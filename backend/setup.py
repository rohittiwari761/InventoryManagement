#!/usr/bin/env python3
"""
Setup script for Inventory Management System Backend
"""

import os
import sys
import subprocess

def run_command(command, description):
    """Run a command and handle errors"""
    print(f"\n{'='*50}")
    print(f"Running: {description}")
    print(f"Command: {command}")
    print(f"{'='*50}")
    
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"✅ {description} completed successfully")
        if result.stdout:
            print(result.stdout)
    else:
        print(f"❌ {description} failed")
        if result.stderr:
            print(f"Error: {result.stderr}")
        return False
    
    return True

def main():
    print("🚀 Setting up Inventory Management System Backend")
    
    # Check if we're in the right directory
    if not os.path.exists('manage.py'):
        print("❌ Error: manage.py not found. Please run this script from the backend directory.")
        sys.exit(1)
    
    # Create virtual environment
    if not os.path.exists('venv'):
        if not run_command('python3 -m venv venv', 'Creating virtual environment'):
            sys.exit(1)
    else:
        print("✅ Virtual environment already exists")
    
    # Install requirements
    activate_cmd = 'source venv/bin/activate' if os.name != 'nt' else 'venv\\Scripts\\activate'
    pip_cmd = f'{activate_cmd} && pip install -r requirements.txt'
    
    if not run_command(pip_cmd, 'Installing Python packages'):
        sys.exit(1)
    
    # Check if .env file exists
    if not os.path.exists('.env'):
        print("\n📝 Creating .env file from .env.example")
        if os.path.exists('.env.example'):
            import shutil
            shutil.copy('.env.example', '.env')
            print("✅ .env file created. Please update it with your database credentials.")
        else:
            print("⚠️  .env.example not found. Please create a .env file manually.")
    
    # Run migrations
    migrate_cmd = f'{activate_cmd} && python manage.py makemigrations'
    if not run_command(migrate_cmd, 'Creating database migrations'):
        sys.exit(1)
    
    migrate_cmd = f'{activate_cmd} && python manage.py migrate'
    if not run_command(migrate_cmd, 'Running database migrations'):
        sys.exit(1)
    
    # Create superuser (optional)
    print("\n🔐 Do you want to create a superuser? (y/n): ", end="")
    create_superuser = input().lower().strip()
    
    if create_superuser in ['y', 'yes']:
        superuser_cmd = f'{activate_cmd} && python manage.py createsuperuser'
        run_command(superuser_cmd, 'Creating superuser')
    
    print("\n🎉 Backend setup completed successfully!")
    print("\n📋 Next steps:")
    print("1. Update the .env file with your database credentials")
    print("2. Make sure PostgreSQL is running")
    print("3. Start the development server:")
    print(f"   {activate_cmd} && python manage.py runserver")
    print("\n🌐 The API will be available at: http://localhost:8000/")
    print("🔧 Admin panel will be available at: http://localhost:8000/admin/")

if __name__ == '__main__':
    main()