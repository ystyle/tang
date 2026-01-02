#!/bin/bash

echo "======================================"
echo "  Tang Middleware Testing Script"
echo "======================================"
echo ""

BASE_URL="http://localhost:10001"

echo "🔐 Testing KeyAuth Middleware..."
echo ""
echo "1. Public endpoint (no auth required):"
curl -s "${BASE_URL}/test/keyauth" | head -3
echo ""
echo ""
echo "2. Protected endpoint (without key):"
curl -s -w "\nHTTP Status: %{http_code}\n" "${BASE_URL}/test/keyauth/protected" | tail -3
echo ""
echo "3. Protected endpoint (with valid key):"
curl -s -H "X-API-Key: test-secret-key-12345" "${BASE_URL}/test/keyauth/protected" | head -3
echo ""
echo "----------------------------------------"
echo ""

echo "🔄 Testing Rewrite Middleware..."
echo ""
echo "1. Rewrite /old/api/data -> /api/data:"
curl -s "${BASE_URL}/old/api/data" | head -3
echo ""
echo ""
echo "2. Rewrite /api/v1/users -> /api/v2/users:"
curl -s "${BASE_URL}/api/v1/users" | head -3
echo ""
echo "----------------------------------------"
echo ""

echo "💾 Testing Cache Middleware..."
echo ""
echo "1. Cached endpoint (check Cache-Control header):"
curl -s -I "${BASE_URL}/test/cache" | grep -i "cache-control\|etag"
echo ""
echo "2. No-cache endpoint:"
curl -s -I "${BASE_URL}/test/nocache" | grep -i "cache-control"
echo ""
echo "3. API endpoint (no cache rule):"
curl -s -I "${BASE_URL}/api/test-cache" | grep -i "cache-control"
echo ""
echo "----------------------------------------"
echo ""

echo "🏷️  Testing ETag Middleware..."
echo ""
echo "Check ETag header:"
curl -s -I "${BASE_URL}/test/etag" | grep -i "etag"
echo ""
echo "----------------------------------------"
echo ""

echo "✅ All tests completed!"
echo ""
echo "To run the server manually:"
echo "  cd /home/ystyle/Code/CangJie/online/tang/examples/middleware_showcase"
echo "  cjpm run"
echo ""
