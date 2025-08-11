#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing Claude Code Guardian Hook (Stop Event) ===${NC}"
echo

HOOK_SCRIPT="./hooks/guardian-hook.js"

if [ ! -f "$HOOK_SCRIPT" ]; then
    echo -e "${RED}Error: guardian-hook.js not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Testing Stop event with messages containing secrets...${NC}"
echo

# Test Stop event with secret in message
echo -e "1. Testing Stop event with AWS key in response..."
input='{
  "messages": [
    {
      "role": "assistant",
      "content": "Here is your AWS key: AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
    }
  ],
  "modelUsage": {}
}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${RED}   ❌ Failed - secret not blocked${NC}"
else
    echo -e "${GREEN}   ✅ Passed - secret blocked${NC}"
fi

# Test Stop event with multiple secrets
echo -e "2. Testing Stop event with multiple secrets..."
input='{
  "messages": [
    {
      "role": "user",
      "content": "Please help me with my code"
    },
    {
      "role": "assistant", 
      "content": "Sure! Here is the config: mongodb://user:pass@localhost:27017"
    },
    {
      "role": "assistant",
      "content": "And your API key is: sk-proj-abcdef123456789"
    }
  ],
  "modelUsage": {}
}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${RED}   ❌ Failed - secrets not blocked${NC}"
else
    echo -e "${GREEN}   ✅ Passed - secrets blocked${NC}"
fi

# Test Stop event with structured content
echo -e "3. Testing Stop event with structured content..."
input='{
  "messages": [
    {
      "role": "assistant",
      "content": [
        {"text": "Here is your token: "},
        {"text": "github_token=ghp_1234567890abcdef"}
      ]
    }
  ],
  "modelUsage": {}
}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${RED}   ❌ Failed - secret in structured content not blocked${NC}"
else
    echo -e "${GREEN}   ✅ Passed - secret in structured content blocked${NC}"
fi

echo
echo -e "${YELLOW}Testing Stop event with safe content...${NC}"
echo

# Test Stop event with safe content
echo -e "4. Testing Stop event with safe response..."
input='{
  "messages": [
    {
      "role": "assistant",
      "content": "I have updated your configuration file with the proper settings."
    }
  ],
  "modelUsage": {}
}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${GREEN}   ✅ Passed - safe content allowed${NC}"
else
    echo -e "${RED}   ❌ Failed - safe content blocked${NC}"
fi

echo
echo -e "${YELLOW}Testing backwards compatibility with PreToolUse...${NC}"
echo

# Test PreToolUse still works
echo -e "5. Testing PreToolUse Write with secret..."
input='{"toolName":"Write","toolInput":{"content":"password: supersecret123"}}'
if echo "$input" | node "$HOOK_SCRIPT" > /dev/null 2>&1; then
    echo -e "${RED}   ❌ Failed - PreToolUse secret not blocked${NC}"
else
    echo -e "${GREEN}   ✅ Passed - PreToolUse secret blocked${NC}"
fi

echo
echo -e "${GREEN}Test complete!${NC}"