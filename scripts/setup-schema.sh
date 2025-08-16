cat > backend/src/database/schema/schema.sql << 'EOF'
-- ============================================================================
-- HappyRepair - PostgreSQL Database Schema
-- Version: 1.0
-- Date: August 16, 2025
-- Description: Complete database schema for HappyRepair MVP
-- ============================================================================

-- Enable UUID extension for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- For location-based queries

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Languages table for internationalization
CREATE TABLE languages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(10) NOT NULL UNIQUE, -- 'en', 'es', 'es-MX'
    name VARCHAR(100) NOT NULL, -- 'English', 'Español'
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default languages
INSERT INTO languages (code, name) VALUES
('en', 'English'),
('es', 'Español'),
('es-MX', 'Español (México)');

-- ============================================================================
-- USER MANAGEMENT
-- ============================================================================

-- Customers table
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255),
    email VARCHAR(255),
    preferred_language VARCHAR(10) DEFAULT 'en' REFERENCES languages(code),
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Mechanics/Shops table
CREATE TABLE mechanics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_name VARCHAR(255) NOT NULL,
    owner_name VARCHAR(255),
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(255),
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    country VARCHAR(50) DEFAULT 'US',

    -- Location data for proximity search
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    location GEOGRAPHY(POINT, 4326), -- PostGIS point for efficient spatial queries

    -- Business information
    business_license VARCHAR(100),
    insurance_provider VARCHAR(255),
    years_in_business INTEGER,

    -- Cultural and language attributes
    preferred_language VARCHAR(10) DEFAULT 'en' REFERENCES languages(code),
    speaks_spanish BOOLEAN DEFAULT false,
    speaks_english BOOLEAN DEFAULT true,
    mexican_owned BOOLEAN DEFAULT false,
    accepts_cash BOOLEAN DEFAULT true,
    accepts_cards BOOLEAN DEFAULT true,

    -- Business metrics
    rating DECIMAL(3,2) DEFAULT 0.0,
    review_count INTEGER DEFAULT 0,
    total_bookings INTEGER DEFAULT 0,

    -- Account status
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    subscription_tier VARCHAR(50) DEFAULT 'free', -- 'free', 'basic', 'premium'
    subscription_expires_at TIMESTAMP WITH TIME ZONE,

    -- Profile media
    profile_image_url TEXT,
    business_photos TEXT[], -- Array of photo URLs

    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Master services list
CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100), -- 'Maintenance', 'Repair', 'Diagnostic', 'Emergency'
    description TEXT,
    estimated_duration INTEGER DEFAULT 60, -- in minutes
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Service translations for internationalization
CREATE TABLE service_translations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    language_code VARCHAR(10) NOT NULL REFERENCES languages(code),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(service_id, language_code)
);

-- Mechanic services and pricing
CREATE TABLE mechanic_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mechanic_id UUID NOT NULL REFERENCES mechanics(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES services(id),
    min_price DECIMAL(8,2) NOT NULL,
    max_price DECIMAL(8,2) NOT NULL,
    parts_cost_min DECIMAL(8,2),
    parts_cost_max DECIMAL(8,2),
    labor_cost_min DECIMAL(8,2),
    labor_cost_max DECIMAL(8,2),
    is_available BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(mechanic_id, service_id),
    CHECK (min_price <= max_price),
    CHECK (parts_cost_min <= parts_cost_max),
    CHECK (labor_cost_min <= labor_cost_max)
);

-- Main bookings table
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    mechanic_id UUID NOT NULL REFERENCES mechanics(id),
    service_id UUID NOT NULL REFERENCES services(id),

    -- Scheduling
    requested_time TIMESTAMP WITH TIME ZONE NOT NULL,
    confirmed_time TIMESTAMP WITH TIME ZONE,
    completed_time TIMESTAMP WITH TIME ZONE,

    -- Status tracking
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN (
        'pending', 'accepted', 'declined', 'confirmed',
        'in_progress', 'completed', 'cancelled', 'no_show'
    )),

    -- Pricing
    estimated_price_min DECIMAL(8,2),
    estimated_price_max DECIMAL(8,2),
    quoted_price DECIMAL(8,2),
    final_price DECIMAL(8,2),

    -- Communication
    customer_notes TEXT,
    mechanic_notes TEXT,
    internal_notes TEXT,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE, -- When mechanic responded
    cancelled_at TIMESTAMP WITH TIME ZONE
);

-- Customer reviews of mechanics
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) UNIQUE, -- One review per booking
    customer_id UUID NOT NULL REFERENCES customers(id),
    mechanic_id UUID NOT NULL REFERENCES mechanics(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_anonymous BOOLEAN DEFAULT false,
    is_published BOOLEAN DEFAULT true,
    is_flagged BOOLEAN DEFAULT false,
    flagged_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SAMPLE DATA INSERTION
-- ============================================================================

-- Insert sample services
INSERT INTO services (name, category, description, estimated_duration) VALUES
('Oil Change', 'Maintenance', 'Standard oil and filter change', 30),
('Brake Inspection', 'Safety', 'Complete brake system inspection', 45),
('Belt Replacement', 'Repair', 'Drive belt or timing belt replacement', 120),
('Tire Rotation', 'Maintenance', 'Rotate tires for even wear', 30),
('Battery Test', 'Diagnostic', 'Battery and charging system test', 20),
('AC Service', 'Repair', 'Air conditioning system service', 90),
('Transmission Service', 'Maintenance', 'Transmission fluid change and inspection', 60),
('Engine Diagnostic', 'Diagnostic', 'Computer diagnostic scan', 30);

-- Insert service translations (Spanish)
INSERT INTO service_translations (service_id, language_code, name, description)
SELECT id, 'es',
    CASE name
        WHEN 'Oil Change' THEN 'Cambio de Aceite'
        WHEN 'Brake Inspection' THEN 'Inspección de Frenos'
        WHEN 'Belt Replacement' THEN 'Reemplazo de Correa'
        WHEN 'Tire Rotation' THEN 'Rotación de Llantas'
        WHEN 'Battery Test' THEN 'Prueba de Batería'
        WHEN 'AC Service' THEN 'Servicio de Aire Acondicionado'
        WHEN 'Transmission Service' THEN 'Servicio de Transmisión'
        WHEN 'Engine Diagnostic' THEN 'Diagnóstico del Motor'
    END,
    CASE description
        WHEN 'Standard oil and filter change' THEN 'Cambio estándar de aceite y filtro'
        WHEN 'Complete brake system inspection' THEN 'Inspección completa del sistema de frenos'
        WHEN 'Drive belt or timing belt replacement' THEN 'Reemplazo de correa de transmisión o distribución'
        WHEN 'Rotate tires for even wear' THEN 'Rotación de llantas para desgaste uniforme'
        WHEN 'Battery and charging system test' THEN 'Prueba de batería y sistema de carga'
        WHEN 'Air conditioning system service' THEN 'Servicio del sistema de aire acondicionado'
        WHEN 'Transmission fluid change and inspection' THEN 'Cambio de fluido de transmisión e inspección'
        WHEN 'Computer diagnostic scan' THEN 'Escaneo de diagnóstico por computadora'
    END
FROM services;

-- Create indexes for performance
CREATE INDEX idx_mechanics_location ON mechanics USING GIST(location);
CREATE INDEX idx_mechanics_active ON mechanics(is_active) WHERE is_active = true;
CREATE INDEX idx_services_active ON services(is_active) WHERE is_active = true;
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_created_at ON bookings(created_at DESC);

SELECT 'Database schema loaded successfully!' as status;
EOF

echo "Schema file created at backend/src/database/schema/schema.sql"