#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing Claude Code Guardian Hook ===${NC}"
echo

# Test the guardian-hook.js with Claude Code format
HOOK_SCRIPT="./hooks/guardian-hook.js"

if [ ! -f "$HOOK_SCRIPT" ]; then
    echo -e "${RED}Error: guardian-hook.js not found${NC}"
    echo "Please run install.sh first"
    exit 1
fi

echo -e "${YELLOW}Testing different tool types with secrets...${NC}"
echo

# Test Write tool with secret
echo -e "1. Testing Write tool with AWS key..."
input='{"toolName":"Write","toolInput":{"file_path":"/tmp/test.txt","content":"AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"}}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${RED}   ❌ Failed - secret not blocked${NC}"
else
    echo -e "${GREEN}   ✅ Passed - secret blocked${NC}"
fi

# Test Edit tool with secret
echo -e "2. Testing Edit tool with API key..."
input='{"toolName":"Edit","toolInput":{"file_path":"/tmp/test.txt","old_string":"foo","new_string":"api_key=sk-proj-abcdef123456789"}}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${RED}   ❌ Failed - secret not blocked${NC}"
else
    echo -e "${GREEN}   ✅ Passed - secret blocked${NC}"
fi

# Test MultiEdit tool with secret
echo -e "3. Testing MultiEdit tool with GitHub token..."
input='{"toolName":"MultiEdit","toolInput":{"file_path":"/tmp/test.txt","edits":[{"old_string":"foo","new_string":"github_token=ghp_1234567890abcdef"}]}}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${RED}   ❌ Failed - secret not blocked${NC}"
else
    echo -e "${GREEN}   ✅ Passed - secret blocked${NC}"
fi

# Test Bash tool with secret
echo -e "4. Testing Bash tool with password in command..."
input='{"toolName":"Bash","toolInput":{"command":"export DB_PASSWORD=supersecret123"}}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${RED}   ❌ Failed - secret not blocked${NC}"
else
    echo -e "${GREEN}   ✅ Passed - secret blocked${NC}"
fi

echo
echo -e "${YELLOW}Testing safe content...${NC}"
echo

# Test Write tool with safe content
echo -e "5. Testing Write tool with safe content..."
input='{"toolName":"Write","toolInput":{"file_path":"/tmp/test.txt","content":"const config = { debug: true };"}}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${GREEN}   ✅ Passed - safe content allowed${NC}"
else
    echo -e "${RED}   ❌ Failed - safe content blocked${NC}"
fi

# Test Bash tool with safe command
echo -e "6. Testing Bash tool with safe command..."
input='{"toolName":"Bash","toolInput":{"command":"ls -la"}}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${GREEN}   ✅ Passed - safe command allowed${NC}"
else
    echo -e "${RED}   ❌ Failed - safe command blocked${NC}"
fi

echo
echo -e "${YELLOW}Testing error output format...${NC}"
echo

# Test to see the actual error output
echo -e "7. Showing error output for blocked secret..."
input='{"toolName":"Write","toolInput":{"file_path":"/tmp/test.txt","content":"mongodb://user:pass@localhost:27017"}}'
echo "$input" | node "$HOOK_SCRIPT" 2>&1 | head -20

echo
echo -e "${GREEN}Test complete!${NC}"