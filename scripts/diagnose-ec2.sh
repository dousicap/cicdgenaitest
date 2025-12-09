#!/bin/bash

# EC2 Diagnostic Script
# This script checks all aspects of your FastAPI deployment on EC2

echo "=========================================="
echo "EC2 FastAPI Deployment Diagnostic"
echo "=========================================="
echo ""

# 1. Check Instance Information
echo "1. INSTANCE INFORMATION"
echo "------------------------"
echo "Hostname: $(hostname)"
echo "Private IP: $(hostname -I | awk '{print $1}')"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'Unable to fetch')"
echo ""

# 2. Check if FastAPI service is running
echo "2. FASTAPI SERVICE STATUS"
echo "------------------------"
if systemctl is-active --quiet fastapi-app; then
    echo "✓ Service is RUNNING"
    sudo systemctl status fastapi-app --no-pager | head -15
else
    echo "✗ Service is NOT RUNNING"
    echo "Checking if service exists..."
    if systemctl list-unit-files | grep -q fastapi-app; then
        echo "Service file exists but is not running"
        echo "Last 20 lines of service logs:"
        sudo journalctl -u fastapi-app -n 20 --no-pager
    else
        echo "Service file does not exist. Application needs to be deployed."
    fi
fi
echo ""

# 3. Check ports
echo "3. PORT STATUS"
echo "------------------------"
echo "Checking port 8000 (FastAPI):"
if sudo netstat -tlnp | grep -q ":8000"; then
    echo "✓ Port 8000 is OPEN"
    sudo netstat -tlnp | grep ":8000"
else
    echo "✗ Port 8000 is NOT listening"
fi
echo ""

echo "Checking port 80 (HTTP/Nginx):"
if sudo netstat -tlnp | grep -q ":80"; then
    echo "✓ Port 80 is OPEN"
    sudo netstat -tlnp | grep ":80"
else
    echo "✗ Port 80 is NOT listening"
fi
echo ""

# 4. Check Nginx
echo "4. NGINX STATUS"
echo "------------------------"
if command -v nginx &> /dev/null; then
    if systemctl is-active --quiet nginx; then
        echo "✓ Nginx is RUNNING"
        sudo systemctl status nginx --no-pager | head -10
    else
        echo "✗ Nginx is installed but NOT RUNNING"
    fi
else
    echo "ℹ Nginx is not installed"
fi
echo ""

# 5. Test local connectivity
echo "5. LOCAL CONNECTIVITY TEST"
echo "------------------------"
echo "Testing FastAPI on port 8000:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 | grep -q "200"; then
    echo "✓ FastAPI responds on localhost:8000"
    echo "Response:"
    curl -s http://localhost:8000 | head -5
else
    echo "✗ FastAPI does not respond on localhost:8000"
fi
echo ""

echo "Testing Nginx on port 80:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "200"; then
    echo "✓ Nginx responds on localhost:80"
    echo "Response:"
    curl -s http://localhost:80 | head -5
else
    echo "✗ Nginx does not respond on localhost:80"
fi
echo ""

# 6. Check application files
echo "6. APPLICATION FILES"
echo "------------------------"
if [ -d "/home/ubuntu/app" ]; then
    echo "✓ Application directory exists: /home/ubuntu/app"
    ls -la /home/ubuntu/app
else
    echo "✗ Application directory NOT FOUND: /home/ubuntu/app"
fi
echo ""

# 7. Check firewall
echo "7. FIREWALL STATUS"
echo "------------------------"
if command -v ufw &> /dev/null; then
    echo "UFW Status:"
    sudo ufw status
else
    echo "ℹ UFW is not installed"
fi
echo ""

# 8. Check security group (from instance metadata)
echo "8. NETWORK & SECURITY"
echo "------------------------"
echo "Instance Metadata Service:"
if curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/ &> /dev/null; then
    echo "✓ Metadata service accessible"
    echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
    echo "Security Groups: $(curl -s http://169.254.169.254/latest/meta-data/security-groups)"
else
    echo "✗ Cannot access metadata service"
fi
echo ""

# 9. Check logs
echo "9. RECENT APPLICATION LOGS"
echo "------------------------"
if [ -f "/var/log/syslog" ]; then
    echo "Last 10 lines mentioning fastapi:"
    sudo grep -i fastapi /var/log/syslog | tail -10 || echo "No fastapi logs found"
fi
echo ""

# 10. Summary and recommendations
echo "=========================================="
echo "DIAGNOSTIC SUMMARY"
echo "=========================================="
echo ""

# Check if application is accessible
APP_RUNNING=false
NGINX_RUNNING=false

if systemctl is-active --quiet fastapi-app && sudo netstat -tlnp | grep -q ":8000"; then
    APP_RUNNING=true
fi

if command -v nginx &> /dev/null && systemctl is-active --quiet nginx && sudo netstat -tlnp | grep -q ":80"; then
    NGINX_RUNNING=true
fi

if [ "$APP_RUNNING" = true ]; then
    echo "✓ FastAPI application is running correctly"
    echo ""
    echo "To access externally, ensure AWS Security Group allows:"
    echo "  - Port 8000 (Custom TCP) from 0.0.0.0/0"
    if [ "$NGINX_RUNNING" = true ]; then
        echo "  - Port 80 (HTTP) from 0.0.0.0/0"
        echo ""
        echo "Access URLs:"
        echo "  - http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
        echo "  - http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
    else
        echo ""
        echo "Access URL:"
        echo "  - http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
    fi
else
    echo "✗ PROBLEM DETECTED: FastAPI application is not running"
    echo ""
    echo "RECOMMENDED ACTIONS:"
    echo "1. Deploy the application using: ./scripts/deploy.sh"
    echo "2. Check service logs: sudo journalctl -u fastapi-app -n 50"
    echo "3. Verify Python dependencies are installed"
fi

echo ""
echo "=========================================="
echo "Diagnostic complete!"
echo "=========================================="
