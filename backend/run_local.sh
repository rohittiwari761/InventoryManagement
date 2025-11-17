#!/bin/bash
# Local Development Server Script

echo "🚀 Starting Inventory Management Backend..."
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "⚠️  Virtual environment not found. Creating one..."
    python3 -m venv venv
    echo "✅ Virtual environment created"
fi

# Activate virtual environment
echo "📦 Activating virtual environment..."
source venv/bin/activate

# Install/update dependencies
echo "📥 Installing dependencies..."
pip install -q -r requirements.txt

# Run migrations
echo "🔄 Running migrations..."
python manage.py migrate

# Start server
echo ""
echo "✅ Backend server starting..."
echo "📍 Local: http://localhost:8000"
echo "📍 Network: http://192.168.1.18:8000"
echo "📍 API: http://192.168.1.18:8000/api"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python manage.py runserver 0.0.0.0:8000
