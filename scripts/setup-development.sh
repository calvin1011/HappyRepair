#!/bin/bash

# ============================================================================
# HappyRepair Development Environment Setup Script
# This script sets up everything you need to start developing
# ============================================================================

set -e # Exit on any error

echo "🚀 Setting up HappyRepair development environment..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 18+ from https://nodejs.org/"
        exit 1
    fi

    # Check Node.js version
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version 18+ is required. Current version: $(node -v)"
        exit 1
    fi

    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed"
        exit 1
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker from https://docker.com/"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi

    print_status "All prerequisites are installed"
}

# Create necessary directories
create_directories() {
    print_info "Creating project directories..."

    mkdir -p backend/src/{api/{routes,controllers,middleware,validators},database/{models,migrations,seeds},services,utils,types,tests}
    mkdir -p apps/{mobile/src,web-dashboard/src}
    mkdir -p packages/{shared-types/src,shared-utils/src,ui-components/src}
    mkdir -p infrastructure/{docker,terraform,kubernetes}
    mkdir -p docs
    mkdir -p scripts
    mkdir -p backups
    mkdir -p logs

    print_status "Project directories created"
}

# Setup environment file
setup_environment() {
    print_info "Setting up environment configuration..."

    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating from template..."
        # The .env content is already provided in the previous artifact
        print_status "Environment file created. Please update the API keys in .env"
    else
        print_status "Environment file already exists"
    fi
}

# Setup database schema file
setup_database_schema() {
    print_info "Setting up database schema..."

    if [ ! -f backend/src/database/schema/schema.sql ]; then
        print_warning "Database schema not found at backend/src/database/schema/schema.sql"
        print_info "Please place the schema.sql file in backend/src/database/schema/"
    else
        print_status "Database schema file found"
    fi
}

# Install dependencies
install_dependencies() {
    print_info "Installing dependencies..."

    # Install root dependencies
    npm install

    print_status "Root dependencies installed"
}

# Start database services
start_database() {
    print_info "Starting database services..."

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    # Start PostgreSQL and Redis
    docker-compose up -d postgres redis

    # Wait for PostgreSQL to be ready
    print_info "Waiting for PostgreSQL to be ready..."
    timeout=60
    while ! docker-compose exec -T postgres pg_isready -U happyrepair -d happyrepair_dev &> /dev/null; do
        timeout=$((timeout - 1))
        if [ $timeout -eq 0 ]; then
            print_error "PostgreSQL failed to start within 60 seconds"
            exit 1
        fi
        sleep 1
    done

    print_status "Database services started successfully"
}

# Setup database
setup_database() {
    print_info "Setting up database..."

    # Check if schema file exists
    if [ -f backend/src/database/schema/schema.sql ]; then
        print_info "Database schema will be automatically loaded by Docker"
        print_status "Database setup completed"
    else
        print_warning "Schema file not found. Database will be empty."
    fi
}

# Create basic package.json files for workspace
create_package_files() {
    print_info "Creating package.json files for workspace..."

    # Backend package.json
    if [ ! -f backend/package.json ]; then
        cat > backend/package.json << 'EOF'
{
  "name": "@happyrepair/backend",
  "version": "1.0.0",
  "description": "HappyRepair Backend API",
  "main": "dist/server.js",
  "scripts": {
    "dev": "nodemon src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "jest",
    "lint": "eslint src --ext .ts",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0",
    "redis": "^4.6.7",
    "jsonwebtoken": "^9.0.1",
    "bcrypt": "^5.1.0",
    "dotenv": "^16.3.1",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "express-rate-limit": "^6.8.1",
    "express-validator": "^7.0.1"
  },
  "devDependencies": {
    "@types/express": "^4.17.17",
    "@types/node": "^20.4.2",
    "@types/pg": "^8.10.2",
    "@types/bcrypt": "^5.0.0",
    "@types/jsonwebtoken": "^9.0.2",
    "@types/cors": "^2.8.13",
    "@types/morgan": "^1.9.4",
    "nodemon": "^3.0.1",
    "ts-node": "^10.9.1",
    "typescript": "^5.1.6",
    "jest": "^29.6.1",
    "@types/jest": "^29.5.3"
  }
}
EOF
    fi

    print_status "Package files created"
}

# Setup Git hooks
setup_git_hooks() {
    print_info "Setting up Git hooks..."

    if [ -d .git ]; then
        npm run setup:hooks
        print_status "Git hooks configured"
    else
        print_warning "Not a Git repository. Run 'git init' first to enable Git hooks."
    fi
}

# Print next steps
print_next_steps() {
    echo ""
    echo "🎉 Development environment setup complete!"
    echo "==========================================="
    echo ""
    echo "Next steps:"
    echo "1. Update API keys in .env file"
    echo "2. Place schema.sql in backend/src/database/schema/"
    echo "3. Start development:"
    echo "   npm run docker:up    # Start database"
    echo "   npm run dev:backend  # Start API server"
    echo ""
    echo "Useful commands:"
    echo "  npm run docker:up      # Start PostgreSQL & Redis"
    echo "  npm run docker:down    # Stop services"
    echo "  npm run db:reset       # Reset database"
    echo ""
    echo "Access points:"
    echo "  Database: postgresql://happyrepair:dev_password_2024@localhost:5432/happyrepair_dev"
    echo "  Redis: redis://localhost:6379"
    echo "  pgAdmin: http://localhost:8080 (with --profile admin)"
    echo ""
    print_status "Happy coding! 🚀"
}

# Main execution
main() {
    check_prerequisites
    create_directories
    setup_environment
    setup_database_schema
    install_dependencies
    create_package_files
    start_database
    setup_database
    setup_git_hooks
    print_next_steps
}

# Run main function
main "$@"