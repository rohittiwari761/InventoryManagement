# 📱 Inventory Management System

A comprehensive, full-featured inventory management system built with **Flutter** (mobile frontend) and **Django** (REST API backend). Perfect for businesses managing multiple companies, stores, and complex inventory operations with GST compliance.

![Flutter](https://img.shields.io/badge/Flutter-3.32.6-blue?logo=flutter)
![Django](https://img.shields.io/badge/Django-4.2.7-green?logo=django)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12+-blue?logo=postgresql)
![License](https://img.shields.io/badge/License-Proprietary-red)

## 🏗️ Project Structure

```
📦 Inventory Management System
├── 🗄️ backend/              # Django REST API Backend
│   ├── apps/                 # Modular Django apps
│   │   ├── accounts/         # User management & authentication
│   │   ├── companies/        # Company management
│   │   ├── stores/          # Store management
│   │   ├── items/           # Item & inventory management
│   │   └── invoices/        # Invoice & GST management
│   ├── inventory_system/    # Django project settings
│   ├── requirements.txt     # Python dependencies
│   └── setup.py            # Automated setup script
│
├── 📱 frontend/             # Flutter Mobile Application
│   ├── lib/
│   │   ├── core/           # App configuration & services
│   │   ├── features/       # Feature-based modules
│   │   └── shared/         # Shared components & models
│   ├── pubspec.yaml        # Flutter dependencies
│   └── android/ios/        # Platform-specific code
│
├── 📚 docs/                # Documentation & assets
├── 🚀 DEPLOYMENT.md        # Comprehensive deployment guide
└── 📖 README.md           # This file
```

## ✨ Key Features

### 👥 Multi-Role User Management
- **🔑 Admin/Owner**: Complete system control, manages all companies and stores
- **🏪 Store Manager**: Manages assigned stores, can create invoices
- **👤 Store User**: View-only access to assigned store inventory

### 🏢 Business Management
- **Multi-company architecture** - One admin can manage multiple companies
- **Multi-store support** - Each company can have multiple stores
- **Hierarchical permissions** - Role-based access at every level
- **User assignment** - Flexible user-to-store assignments

### 📦 Advanced Inventory Management
- **Company-level items** with store-level quantities
- **Real-time inventory tracking** with transaction history
- **Low stock alerts** and automated notifications
- **Multiple units support** (kg, pieces, liters, etc.)
- **SKU and HSN code management**

### 🧾 GST-Compliant Invoicing
- **Automatic tax calculations** (CGST, SGST, IGST)
- **Inter/Intra-state GST rules** compliance
- **Professional PDF generation** with company branding
- **Invoice numbering**: `INV/COMP001/STORE01/0001`
- **Customer management** with GSTIN validation
- **Multiple invoice statuses** (Draft, Sent, Paid, Cancelled)

### 🔐 Security & Authentication
- **JWT-based authentication** with refresh tokens
- **Role-based permissions** at API level
- **Secure password handling** with Django's built-in security
- **Session management** with automatic logout

## 🛠️ Technology Stack

### Backend (Django)
| Component | Technology | Version |
|-----------|------------|---------|
| **Framework** | Django + DRF | 4.2.7 |
| **Database** | PostgreSQL | 12+ |
| **Authentication** | JWT | SimpleJWT |
| **PDF Generation** | ReportLab | 4.0.4 |
| **API Documentation** | Django Admin | Built-in |

### Frontend (Flutter)
| Component | Technology | Version |
|-----------|------------|---------|
| **Framework** | Flutter | 3.32.6 |
| **State Management** | Provider + Bloc | 8.1.3 |
| **HTTP Client** | Dio | 5.3.2 |
| **UI Framework** | Material Design 3 | Built-in |
| **Local Storage** | SharedPreferences + Hive | 2.2.2 |

## 🚀 Quick Start

### 🐳 Docker Setup (Recommended)
**No installation required - just Docker!**
```bash
# Clone the repository
git clone <repository-url>
cd inventory-management-system

# Start everything with one command
chmod +x docker-run.sh
./docker-run.sh start
```

**Access Points:**
- **Frontend**: http://localhost:8080
- **Backend API**: http://localhost:8000
- **Admin Panel**: http://localhost:8000/admin
- **Default Login**: admin@inventory.com / admin123

### 📖 Traditional Setup

#### Prerequisites
- Python 3.8+
- Flutter SDK 3.0+
- PostgreSQL 12+
- Android Studio / Xcode (for mobile development)

#### 1️⃣ Backend Setup
```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Configure database
cp .env.example .env
# Edit .env with your database credentials

# Setup database
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser

# Start server
python manage.py runserver
```

#### 2️⃣ Frontend Setup
```bash
cd frontend
flutter doctor  # Ensure Flutter is properly installed
flutter pub get

# Start app (with backend running)
flutter run
```

#### 3️⃣ Access Points
- **API Server**: http://localhost:8000/
- **Admin Panel**: http://localhost:8000/admin/
- **Mobile App**: On connected device/emulator

## 📚 API Documentation

### Authentication Endpoints
- `POST /api/auth/login/` - User login
- `POST /api/auth/register/` - User registration  
- `POST /api/auth/logout/` - User logout
- `GET /api/auth/profile/` - Get user profile

### Business Endpoints
- `GET/POST /api/companies/` - Company management
- `GET/POST /api/stores/` - Store management
- `GET/POST /api/items/` - Item management
- `GET/POST /api/invoices/` - Invoice management

### Special Features
- `GET /api/items/inventory/low-stock/` - Low stock alerts
- `POST /api/invoices/{id}/pdf/` - Generate invoice PDF
- `GET /api/invoices/stats/` - Invoice statistics

## 🎯 Business Use Cases

### For Small Businesses
- Single company with multiple stores
- Basic inventory tracking
- GST-compliant invoicing
- Simple user management

### For Enterprise
- Multiple companies under one admin
- Complex role hierarchies
- Advanced inventory analytics
- Multi-location management

### For Distributors
- Multi-company inventory
- Store-wise stock allocation
- Detailed transaction tracking
- Customer relationship management

## 🔧 Development Features

### Code Quality
- **Modular architecture** with separation of concerns
- **Type safety** with Dart and Python type hints
- **Error handling** at all levels
- **Logging and monitoring** capabilities

### Testing Ready
- Unit tests structure in place
- API endpoint testing setup
- Flutter widget testing ready
- Integration testing support

## 📱 Mobile Features

### User Experience
- **Responsive design** for all screen sizes
- **Offline capability** with local caching
- **Dark/Light theme** support
- **Professional UI** with Material Design 3

### Performance
- **Optimized API calls** with caching
- **Image optimization** for company logos
- **Lazy loading** for large datasets
- **Background sync** capabilities

## 🛡️ Security Features

- **JWT token authentication** with automatic refresh
- **Role-based access control** at database level
- **Input validation** and sanitization
- **CORS configuration** for API security
- **SQL injection protection** with Django ORM

## 📈 Scalability

- **Horizontal scaling** ready architecture
- **Database optimization** with proper indexing
- **API rate limiting** capabilities
- **Caching layer** support
- **Load balancer** ready

## 🚀 Deployment

### 🐳 Docker Deployment (Recommended)
See [DOCKER.md](DOCKER.md) for comprehensive Docker instructions:
- One-command setup with Docker
- Development, staging, and production environments
- Database backups and maintenance
- SSL and domain configuration
- Monitoring and troubleshooting

### 🌐 Traditional Deployment
See [DEPLOYMENT.md](DEPLOYMENT.md) for traditional deployment:
- Manual server setup
- Cloud deployment (Railway, Heroku, AWS)
- Mobile app store submission
- CI/CD pipeline setup

## 🤝 Contributing

This is a proprietary project. For feature requests or bug reports, please contact the development team.

## 📄 License

This project is proprietary and confidential. All rights reserved.

## 🆘 Support

For technical support or questions:
- Check the [DEPLOYMENT.md](DEPLOYMENT.md) guide
- Review the API documentation at `/admin/doc/`
- Contact the development team

---

**Built with ❤️ using Flutter & Django**