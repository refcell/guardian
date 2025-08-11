#!/bin/bash

echo "Testing Secrets Guardian Hook..."
echo

# Test cases
declare -a test_cases=(
    "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
    "api_key = 'sk-proj-abcdef123456789'"
    "password: supersecret123"
    "mongodb://user:pass@localhost:27017"
    "github_token=ghp_1234567890abcdef"
    "-----BEGIN RSA PRIVATE KEY-----"
)

for test in "${test_cases[@]}"; do
    echo "Testing: ${test:0:30}..."
    result=$(echo "$test" | node hooks/secure-command.js 2>&1)
    status=$?
    
    if [ $status -ne 0 ]; then
        echo "✅ Secret detected and blocked!"
    else
        echo "⚠️  Secret not detected"
    fi
    echo "$result" | jq -r '.status' 2>/dev/null || echo "$result"
    echo "---"
done

echo
echo "Testing safe content..."
result=$(echo "const config = { debug: true };" | node hooks/secure-command.js 2>&1)
status=$?

if [ $status -eq 0 ]; then
    echo "✅ Safe content passed!"
else
    echo "❌ Safe content was blocked"
fi