#!/bin/bash

# Direct test of Guardian hook with various input formats
# This tests the hook directly without going through Claude Code

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

HOOK_SCRIPT="$HOME/.claude/hooks/guardian-hook.js"

echo -e "${BLUE}=== Direct Hook Testing ===${NC}"
echo

# Test with safe content first
echo -e "${CYAN}Test: PreToolUse Write with safe content${NC}"
TEST_INPUT='{"tool_name":"Write","tool_input":{"content":"const hello = \"world\";","file_path":"test.js"}}'
echo "Input: $TEST_INPUT"
if echo "$TEST_INPUT" | node "$HOOK_SCRIPT" 2>&1; then
    echo -e "${GREEN}✅ Correctly allowed (exit code 0)${NC}"
else
    echo -e "${RED}❌ Should have passed${NC}"
fi
echo

# Test with a secret (constructed at runtime to avoid detection)
echo -e "${CYAN}Test: PreToolUse Write with secret${NC}"
SECRET_PREFIX="AWS_ACCESS_KEY_ID=AKIA"
SECRET_SUFFIX="IOSFODNN7EXAMPLE"
TEST_INPUT="{\"tool_name\":\"Write\",\"tool_input\":{\"content\":\"${SECRET_PREFIX}${SECRET_SUFFIX}\",\"file_path\":\"test.txt\"}}"
echo "Input: [REDACTED FOR SAFETY]"
if echo "$TEST_INPUT" | node "$HOOK_SCRIPT" 2>&1; then
    echo -e "${RED}❌ Should have blocked (exit code 2)${NC}"
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 2 ]; then
        echo -e "${GREEN}✅ Correctly blocked with exit code 2${NC}"
    else
        echo -e "${YELLOW}⚠️  Blocked but with exit code $EXIT_CODE (expected 2)${NC}"
    fi
fi
echo

echo -e "${BLUE}=== Test Complete ===${NC}"
echo
echo -e "${YELLOW}To test more scenarios, run:${NC}"
echo "  ./test-comprehensive.sh"