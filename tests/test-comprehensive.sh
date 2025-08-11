#!/bin/bash

# Comprehensive test suite for Guardian hooks
# Tests all hook types and event formats

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
CLAUDE_CONFIG_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_CONFIG_DIR/hooks"
HOOK_SCRIPT="$HOOKS_DIR/guardian-hook.js"
DEBUG_LOG="$CLAUDE_CONFIG_DIR/guardian-debug.log"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Enable debug mode
export GUARDIAN_DEBUG=true

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Guardian Hook Comprehensive Test Suite v2.0        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo

# Check if hook is installed
if [ ! -f "$HOOK_SCRIPT" ]; then
    echo -e "${RED}❌ Error: Hook not installed at $HOOK_SCRIPT${NC}"
    echo -e "${YELLOW}Please run the installer first:${NC}"
    echo "  ./install-v2.sh --debug"
    exit 1
fi

# Clear debug log
> "$DEBUG_LOG" 2>/dev/null || true

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_input="$2"
    local expected_result="$3"  # "block" or "pass"
    local description="$4"
    
    ((TOTAL_TESTS++))
    
    echo -n "  $test_name: "
    
    # Run the hook
    local exit_code=0
    local output
    output=$(echo "$test_input" | node "$HOOK_SCRIPT" 2>&1) || exit_code=$?
    
    if [ "$expected_result" = "block" ]; then
        if [ $exit_code -eq 2 ]; then
            echo -e "${GREEN}✅ Correctly blocked${NC}"
            ((PASSED_TESTS++))
        else
            echo -e "${RED}❌ Should have blocked (exit: $exit_code)${NC}"
            echo -e "    ${YELLOW}Input: ${test_input:0:100}...${NC}"
            if [ -n "$output" ]; then
                echo -e "    ${YELLOW}Output: $output${NC}"
            fi
            ((FAILED_TESTS++))
        fi
    else
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}✅ Correctly passed${NC}"
            ((PASSED_TESTS++))
        else
            echo -e "${RED}❌ Should have passed (exit: $exit_code)${NC}"
            echo -e "    ${YELLOW}Input: ${test_input:0:100}...${NC}"
            if [ -n "$output" ]; then
                echo -e "    ${YELLOW}Output: $output${NC}"
            fi
            ((FAILED_TESTS++))
        fi
    fi
}

# Test category header
test_category() {
    echo
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
}

# 1. PreToolUse Event Tests
test_category "PreToolUse Events"

run_test "Write safe content" \
    '{"tool_name":"Write","tool_input":{"content":"function hello() { return \"world\"; }"}}' \
    "pass" \
    "Writing safe JavaScript code"

run_test "Write with AWS key" \
    '{"tool_name":"Write","tool_input":{"content":"AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"}}' \
    "block" \
    "Writing file with AWS credentials"

run_test "Edit with API key" \
    '{"tool_name":"Edit","tool_input":{"new_string":"api_key = \"sk-proj-1234567890abcdef\""}}' \
    "block" \
    "Editing file to add API key"

run_test "MultiEdit with GitHub token" \
    '{"tool_name":"MultiEdit","tool_input":{"edits":[{"new_string":"GITHUB_TOKEN=ghp_1234567890abcdef"}]}}' \
    "block" \
    "Multi-edit with GitHub token"

run_test "Bash with safe command" \
    '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
    "pass" \
    "Running safe bash command"

run_test "Bash with password" \
    '{"tool_name":"Bash","tool_input":{"command":"mysql -u root -pMyPassword123!"}}' \
    "block" \
    "Bash command with password"

run_test "Task with safe prompt" \
    '{"tool_name":"Task","tool_input":{"prompt":"Please analyze this code for bugs"}}' \
    "pass" \
    "Task with safe prompt"

run_test "Task with secret" \
    '{"tool_name":"Task","tool_input":{"prompt":"Use this key: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"}}' \
    "block" \
    "Task prompt containing JWT token"

# 2. Stop Event Tests
test_category "Stop Events"

run_test "Stop with safe response" \
    '{"messages":[{"role":"assistant","content":"Here is how to configure your application"}]}' \
    "pass" \
    "Claude response without secrets"

run_test "Stop with API key" \
    '{"messages":[{"role":"assistant","content":"Your API key is: sk-proj-abcdef123456"}]}' \
    "block" \
    "Claude response containing API key"

run_test "Stop with multiple messages" \
    '{"messages":[{"role":"user","content":"What is my password?"},{"role":"assistant","content":"password: SuperSecret123!"}]}' \
    "block" \
    "Multiple messages with password"

run_test "Stop with structured content" \
    '{"messages":[{"role":"assistant","content":[{"text":"AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI"}]}]}' \
    "block" \
    "Structured content with AWS secret"

# 3. UserPromptSubmit Event Tests
test_category "UserPromptSubmit Events"

run_test "User prompt safe" \
    '{"prompt":"How do I implement authentication?"}' \
    "pass" \
    "Safe user question"

run_test "User prompt with password" \
    '{"prompt":"My database password is P@ssw0rd123"}' \
    "block" \
    "User prompt containing password"

run_test "User prompt with connection string" \
    '{"prompt":"Connect to mongodb://admin:secret@localhost:27017"}' \
    "block" \
    "User prompt with MongoDB connection"

# 4. SubagentStop Event Tests
test_category "SubagentStop Events"

run_test "Subagent safe response" \
    '{"messages":[{"role":"assistant","content":"Task completed successfully"}],"subagent_id":"test-123"}' \
    "pass" \
    "Subagent response without secrets"

run_test "Subagent with private key" \
    '{"messages":[{"role":"assistant","content":"-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA"}]}' \
    "block" \
    "Subagent response with private key"

# 5. Edge Cases and Special Patterns
test_category "Edge Cases and Special Patterns"

run_test "Empty input" \
    '{}' \
    "pass" \
    "Empty JSON object"

run_test "Null values" \
    '{"tool_name":"Write","tool_input":{"content":null}}' \
    "pass" \
    "Null content value"

run_test "Base64 encoded secret" \
    '{"tool_name":"Write","tool_input":{"content":"QVdTX0FDQ0VTU19LRVlfSUQ9QUtJQUlPU0ZPRE5ON0VYQU1QTEU="}}' \
    "pass" \
    "Base64 encoded content (not detected as plain text)"

run_test "Secret in JSON string" \
    '{"tool_name":"Write","tool_input":{"content":"{\"apiKey\":\"ghp_1234567890abcdef\"}"}}' \
    "block" \
    "Secret embedded in JSON"

run_test "Multiple secrets" \
    '{"tool_name":"Write","tool_input":{"content":"key1=AKIAIOSFODNN7EXAMPLE\nkey2=ghp_1234567890abcdef"}}' \
    "block" \
    "Multiple different secrets"

run_test "PostgreSQL connection" \
    '{"tool_name":"Bash","tool_input":{"command":"psql postgres://user:password@localhost/db"}}' \
    "block" \
    "PostgreSQL connection string"

run_test "MySQL connection" \
    '{"tool_name":"Write","tool_input":{"content":"mysql://root:rootpass@mysql:3306/database"}}' \
    "block" \
    "MySQL connection string"

run_test "Private key header" \
    '{"tool_name":"Write","tool_input":{"content":"-----BEGIN EC PRIVATE KEY-----"}}' \
    "block" \
    "EC private key header"

run_test "Slack token" \
    '{"tool_name":"Write","tool_input":{"content":"SLACK_TOKEN=xoxb-12345-67890-abcdef"}}' \
    "block" \
    "Slack bot token"

# 6. Performance Tests
test_category "Performance Tests"

# Generate large content
large_safe_content=$(python3 -c "print('const x = 1;\\n' * 1000)")
run_test "Large safe content" \
    "{\"tool_name\":\"Write\",\"tool_input\":{\"content\":\"$large_safe_content\"}}" \
    "pass" \
    "Large file without secrets"

large_secret_content=$(python3 -c "print('const x = 1;\\n' * 999 + 'AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE')")
run_test "Large content with secret" \
    "{\"tool_name\":\"Write\",\"tool_input\":{\"content\":\"$large_secret_content\"}}" \
    "block" \
    "Large file with secret at end"

# 7. Real-world Scenarios
test_category "Real-world Scenarios"

run_test "Docker compose with env" \
    '{"tool_name":"Write","tool_input":{"content":"environment:\n  - API_KEY=${API_KEY}"}}' \
    "pass" \
    "Docker compose with env variable reference"

run_test "Docker compose with hardcoded" \
    '{"tool_name":"Write","tool_input":{"content":"environment:\n  - API_KEY=sk-proj-12345"}}' \
    "block" \
    "Docker compose with hardcoded secret"

run_test "Git config safe" \
    '{"tool_name":"Bash","tool_input":{"command":"git config user.email user@example.com"}}' \
    "pass" \
    "Git configuration command"

run_test "Git with token" \
    '{"tool_name":"Bash","tool_input":{"command":"git clone https://ghp_1234567890abcdef@github.com/user/repo"}}' \
    "block" \
    "Git clone with embedded token"

# Check debug log
echo
test_category "Debug Log Analysis"

if [ -f "$DEBUG_LOG" ]; then
    log_lines=$(wc -l < "$DEBUG_LOG")
    echo -e "  Debug log entries: ${CYAN}$log_lines${NC}"
    
    # Show last few log entries
    echo -e "  Last 5 log entries:"
    tail -5 "$DEBUG_LOG" | while IFS= read -r line; do
        echo -e "    ${YELLOW}$line${NC}"
    done
else
    echo -e "  ${YELLOW}No debug log found${NC}"
fi

# Summary
echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Test Summary                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "  Total Tests:    ${CYAN}$TOTAL_TESTS${NC}"
echo -e "  Passed:         ${GREEN}$PASSED_TESTS${NC}"
echo -e "  Failed:         ${RED}$FAILED_TESTS${NC}"
if [ $SKIPPED_TESTS -gt 0 ]; then
    echo -e "  Skipped:        ${YELLOW}$SKIPPED_TESTS${NC}"
fi

success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "  Success Rate:   ${CYAN}${success_rate}%${NC}"

echo
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! The Guardian hook is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed. Please review the failures above.${NC}"
    echo -e "${YELLOW}Debug log available at: $DEBUG_LOG${NC}"
    exit 1
fi