#!/bin/bash
read -rp "Enter subdomain (e.g., www, home, auth): " subdomain
domain="$subdomain.bedrosn.com"
echo "Checking certificate for $domain..."
echo
echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -subject -dates
