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

-- Customer vehicles
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    year INTEGER,
    make VARCHAR(100),
    model VARCHAR(100),
    trim VARCHAR(100),
    color VARCHAR(50),
    license_plate VARCHAR(20),
    vin VARCHAR(17),
    notes TEXT,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- BUSINESS HOURS AND AVAILABILITY
-- ============================================================================

-- Business hours for mechanics
CREATE TABLE business_hours (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mechanic_id UUID NOT NULL REFERENCES mechanics(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=Sunday, 6=Saturday
    open_time TIME,
    close_time TIME,
    is_closed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(mechanic_id, day_of_week)
);

-- Special hours (holidays, temporary closures, etc.)
CREATE TABLE special_hours (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mechanic_id UUID NOT NULL REFERENCES mechanics(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    reason VARCHAR(255), -- 'Holiday', 'Vacation', 'Emergency Closure'
    is_closed BOOLEAN DEFAULT true,
    special_open_time TIME,
    special_close_time TIME,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(mechanic_id, date)
);

-- ============================================================================
-- SERVICES AND PRICING
-- ============================================================================

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

-- ============================================================================
-- BOOKINGS AND APPOINTMENTS
-- ============================================================================

-- Main bookings table
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    mechanic_id UUID NOT NULL REFERENCES mechanics(id),
    vehicle_id UUID REFERENCES vehicles(id),
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

-- Booking status history for tracking changes
CREATE TABLE booking_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    old_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    changed_by_user_id UUID, -- Could be customer_id or mechanic_id
    changed_by_user_type VARCHAR(20), -- 'customer', 'mechanic', 'system'
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- COMMUNICATION AND NOTIFICATIONS
-- ============================================================================

-- In-app messages between customers and mechanics
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL, -- customer_id or mechanic_id
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('customer', 'mechanic')),
    recipient_id UUID NOT NULL,
    recipient_type VARCHAR(20) NOT NULL CHECK (recipient_type IN ('customer', 'mechanic')),
    message_text TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notification templates for different events
CREATE TABLE notification_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_key VARCHAR(100) NOT NULL, -- 'booking_request', 'booking_accepted', etc.
    language_code VARCHAR(10) NOT NULL REFERENCES languages(code),
    channel VARCHAR(20) NOT NULL CHECK (channel IN ('push', 'sms', 'whatsapp', 'email')),
    title VARCHAR(255),
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(template_key, language_code, channel)
);

-- Notification log
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- customer_id or mechanic_id
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('customer', 'mechanic')),
    booking_id UUID REFERENCES bookings(id),
    template_key VARCHAR(100),
    channel VARCHAR(20) NOT NULL,
    title VARCHAR(255),
    message TEXT NOT NULL,
    is_sent BOOLEAN DEFAULT false,
    sent_at TIMESTAMP WITH TIME ZONE,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    external_id VARCHAR(255), -- For tracking SMS/push notification IDs
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- REVIEWS AND RATINGS
-- ============================================================================

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
-- PAYMENT AND FINANCIAL
-- ============================================================================

-- Payment methods for users
CREATE TABLE payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- customer_id or mechanic_id
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('customer', 'mechanic')),
    method_type VARCHAR(50) NOT NULL, -- 'credit_card', 'debit_card', 'bank_account', 'cash', 'oxxo_pay'
    stripe_payment_method_id VARCHAR(255), -- Stripe token
    last_four VARCHAR(4),
    brand VARCHAR(50), -- 'visa', 'mastercard', etc.
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Transaction records
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    mechanic_id UUID NOT NULL REFERENCES mechanics(id),

    -- Amounts in cents to avoid floating point issues
    service_amount_cents INTEGER NOT NULL,
    tip_amount_cents INTEGER DEFAULT 0,
    tax_amount_cents INTEGER DEFAULT 0,
    total_amount_cents INTEGER NOT NULL,

    -- Platform fees
    platform_fee_cents INTEGER DEFAULT 0,
    platform_fee_percentage DECIMAL(5,4) DEFAULT 0.0300, -- 3%

    -- Payment processing
    payment_method_id UUID REFERENCES payment_methods(id),
    stripe_payment_intent_id VARCHAR(255),
    payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN (
        'pending', 'processing', 'succeeded', 'failed', 'cancelled', 'refunded'
    )),

    -- Currency
    currency VARCHAR(3) DEFAULT 'USD',

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- SYSTEM TABLES
-- ============================================================================

-- System configuration
CREATE TABLE system_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT,
    description TEXT,
    is_public BOOLEAN DEFAULT false, -- Can be accessed by client apps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- API rate limiting
CREATE TABLE rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    ip_address INET,
    endpoint VARCHAR(255) NOT NULL,
    request_count INTEGER DEFAULT 1,
    window_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, endpoint, window_start),
    UNIQUE(ip_address, endpoint, window_start)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Customer indexes
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_active ON customers(is_active) WHERE is_active = true;

-- Mechanic indexes
CREATE INDEX idx_mechanics_location ON mechanics USING GIST(location);
CREATE INDEX idx_mechanics_city_state ON mechanics(city, state);
CREATE INDEX idx_mechanics_active ON mechanics(is_active) WHERE is_active = true;
CREATE INDEX idx_mechanics_verified ON mechanics(is_verified) WHERE is_verified = true;
CREATE INDEX idx_mechanics_rating ON mechanics(rating DESC);

-- Booking indexes
CREATE INDEX idx_bookings_customer ON bookings(customer_id);
CREATE INDEX idx_bookings_mechanic ON bookings(mechanic_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_requested_time ON bookings(requested_time);
CREATE INDEX idx_bookings_created_at ON bookings(created_at DESC);

-- Service indexes
CREATE INDEX idx_mechanic_services_mechanic ON mechanic_services(mechanic_id);
CREATE INDEX idx_mechanic_services_service ON mechanic_services(service_id);
CREATE INDEX idx_mechanic_services_available ON mechanic_services(is_available) WHERE is_available = true;

-- Review indexes
CREATE INDEX idx_reviews_mechanic ON reviews(mechanic_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);
CREATE INDEX idx_reviews_published ON reviews(is_published) WHERE is_published = true;

-- Notification indexes
CREATE INDEX idx_notifications_user ON notifications(user_id, user_type);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE is_read = false;
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update trigger to all tables with updated_at
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_mechanics_updated_at BEFORE UPDATE ON mechanics FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_business_hours_updated_at BEFORE UPDATE ON business_hours FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_services_updated_at BEFORE UPDATE ON services FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_mechanic_services_updated_at BEFORE UPDATE ON mechanic_services FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON payment_methods FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update mechanic location point from lat/lng
CREATE OR REPLACE FUNCTION update_mechanic_location()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_mechanic_location_trigger
    BEFORE INSERT OR UPDATE ON mechanics
    FOR EACH ROW EXECUTE FUNCTION update_mechanic_location();

-- Function to update mechanic rating when new review is added
CREATE OR REPLACE FUNCTION update_mechanic_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE mechanics SET
        rating = (
            SELECT ROUND(AVG(rating)::numeric, 2)
            FROM reviews
            WHERE mechanic_id = NEW.mechanic_id AND is_published = true
        ),
        review_count = (
            SELECT COUNT(*)
            FROM reviews
            WHERE mechanic_id = NEW.mechanic_id AND is_published = true
        )
    WHERE id = NEW.mechanic_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_mechanic_rating_trigger
    AFTER INSERT OR UPDATE ON reviews
    FOR EACH ROW EXECUTE FUNCTION update_mechanic_rating();

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

-- Insert notification templates
INSERT INTO notification_templates (template_key, language_code, channel, title, message) VALUES
-- English templates
('booking_request', 'en', 'push', 'New Booking Request', 'You have a new booking request for {service} on {date}'),
('booking_accepted', 'en', 'push', 'Booking Confirmed!', 'Your booking with {mechanic_name} has been confirmed for {date}'),
('booking_declined', 'en', 'push', 'Booking Update', 'Your booking request has been declined. Please try another mechanic.'),
('booking_reminder', 'en', 'sms', 'Appointment Reminder', 'Reminder: Your appointment with {mechanic_name} is tomorrow at {time}'),

-- Spanish templates
('booking_request', 'es', 'push', 'Nueva Solicitud de Cita', 'Tienes una nueva solicitud para {service} el {date}'),
('booking_accepted', 'es', 'push', '¡Cita Confirmada!', 'Tu cita con {mechanic_name} ha sido confirmada para el {date}'),
('booking_declined', 'es', 'push', 'Actualización de Cita', 'Tu solicitud de cita ha sido rechazada. Por favor intenta con otro mecánico.'),
('booking_reminder', 'es', 'sms', 'Recordatorio de Cita', 'Recordatorio: Tu cita con {mechanic_name} es mañana a las {time}');

-- Insert system configuration
INSERT INTO system_config (config_key, config_value, description, is_public) VALUES
('max_search_radius_miles', '25', 'Maximum search radius for finding mechanics', true),
('booking_advance_hours', '1', 'Minimum hours in advance for bookings', true),
('platform_fee_percentage', '0.03', 'Platform fee percentage (3%)', false),
('sms_verification_expiry_minutes', '10', 'SMS verification code expiry time', false),
('max_daily_bookings_per_mechanic', '20', 'Maximum bookings per mechanic per day', true);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View for active mechanics with their service offerings
CREATE VIEW active_mechanics_with_services AS
SELECT
    m.id,
    m.business_name,
    m.address,
    m.city,
    m.state,
    m.latitude,
    m.longitude,
    m.rating,
    m.review_count,
    m.speaks_spanish,
    m.mexican_owned,
    m.accepts_cash,
    array_agg(DISTINCT s.name) as services,
    min(ms.min_price) as min_service_price,
    max(ms.max_price) as max_service_price
FROM mechanics m
JOIN mechanic_services ms ON m.id = ms.mechanic_id
JOIN services s ON ms.service_id = s.id
WHERE m.is_active = true
    AND m.is_verified = true
    AND ms.is_available = true
GROUP BY m.id;

-- View for booking summary with customer and mechanic details
CREATE VIEW booking_summary AS
SELECT
    b.id,
    b.status,
    b.requested_time,
    b.confirmed_time,
    b.estimated_price_min,
    b.estimated_price_max,
    b.final_price,

    c.name as customer_name,
    c.phone as customer_phone,

    m.business_name as mechanic_name,
    m.phone as mechanic_phone,
    m.address as mechanic_address,

    s.name as service_name,
    s.category as service_category,

    v.year as vehicle_year,
    v.make as vehicle_make,
    v.model as vehicle_model,

    b.created_at,
    b.updated_at
FROM bookings b
JOIN customers c ON b.customer_id = c.id
JOIN mechanics m ON b.mechanic_id = m.id
JOIN services s ON b.service_id = s.id
LEFT JOIN vehicles v ON b.vehicle_id = v.id;

-- ============================================================================
-- FUNCTIONS FOR COMMON OPERATIONS
-- ============================================================================

-- Function to find mechanics within radius
CREATE OR REPLACE FUNCTION find_mechanics_within_radius(
    search_lat DECIMAL,
    search_lng DECIMAL,
    radius_miles INTEGER DEFAULT 10,
    service_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    business_name TEXT,
    distance_miles DECIMAL,
    rating DECIMAL,
    min_price DECIMAL,
    max_price DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id,
        m.business_name::TEXT,
        ROUND((ST_Distance(
            m.location,
            ST_SetSRID(ST_MakePoint(search_lng, search_lat), 4326)
        ) * 0.000621371)::numeric, 2) as distance_miles, -- Convert meters to miles
        m.rating,
        MIN(ms.min_price) as min_price,
        MAX(ms.max_price) as max_price
    FROM mechanics m
    JOIN mechanic_services ms ON m.id = ms.mechanic_id
    JOIN services s ON ms.service_id = s.id
    WHERE m.is_active = true
        AND m.is_verified = true
        AND ms.is_available = true
        AND ST_DWithin(
            m.location,
            ST_SetSRID(ST_MakePoint(search_lng, search_lat), 4326),
            radius_miles * 1609.34 -- Convert miles to meters
        )
        AND (service_filter IS NULL OR s.name ILIKE '%' || service_filter || '%')
    GROUP BY m.id, m.business_name, m.location, m.rating
    ORDER BY distance_miles ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

-- Performance analysis query
SELECT 'Database schema created successfully for HappyRepair MVP' as status;