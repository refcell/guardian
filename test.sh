#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Claude configuration directory
CLAUDE_CONFIG_DIR="$HOME/.config/claude"
HOOKS_DIR="$CLAUDE_CONFIG_DIR/hooks"
AGENTS_DIR="$CLAUDE_CONFIG_DIR/agents"

echo -e "${BLUE}=== Claude Secrets Guardian Hook Test Suite ===${NC}"
echo

# Check if hook is installed
if [ ! -f "$HOOKS_DIR/secure-command.js" ]; then
    echo -e "${RED}❌ Error: Hook not installed at $HOOKS_DIR/secure-command.js${NC}"
    echo -e "${YELLOW}Please run the installer first:${NC}"
    echo "  curl -sSL https://raw.githubusercontent.com/refcell/guardian/main/install.sh | bash"
    exit 1
fi

if [ ! -f "$AGENTS_DIR/secrets-guardian.json" ]; then
    echo -e "${RED}❌ Error: Agent config not found at $AGENTS_DIR/secrets-guardian.json${NC}"
    echo -e "${YELLOW}Please run the installer first:${NC}"
    echo "  curl -sSL https://raw.githubusercontent.com/refcell/guardian/main/install.sh | bash"
    exit 1
fi

echo -e "${GREEN}✅ Hook installation verified${NC}"
echo

# Test cases with secrets that should be blocked
echo -e "${CYAN}Testing Secret Detection:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

declare -a secret_tests=(
    "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE|AWS Access Key"
    "aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY|AWS Secret Key"
    "api_key = 'sk-proj-abcdef123456789012345'|OpenAI API Key"
    "GITHUB_TOKEN=ghp_1234567890abcdef1234567890abcdef12|GitHub Token"
    "slack_token=xoxb-12345-12345-abcdefghijklmnop|Slack Token"
    "password: MySuper\$ecretP@ssw0rd123|Password"
    "mongodb://user:pass@localhost:27017/database|MongoDB Connection"
    "postgres://user:password@localhost:5432/mydb|PostgreSQL Connection"
    "-----BEGIN RSA PRIVATE KEY-----|RSA Private Key"
    "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U|JWT Token"
)

failed_tests=0
passed_tests=0

for test_case in "${secret_tests[@]}"; do
    IFS='|' read -r secret description <<< "$test_case"
    
    echo -n "• Testing ${description}: "
    
    # Run the test
    result=$(echo "$secret" | node "$HOOKS_DIR/secure-command.js" 2>&1)
    status=$?
    
    # Extract JSON status if available
    json_status=$(echo "$result" | grep -o '"status":\s*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' 2>/dev/null)
    
    if [ $status -ne 0 ] || [ "$json_status" = "danger" ]; then
        echo -e "${GREEN}✅ Blocked${NC}"
        ((passed_tests++))
    else
        echo -e "${RED}❌ NOT BLOCKED (This secret should be detected!)${NC}"
        ((failed_tests++))
    fi
done

echo
echo -e "${CYAN}Testing Safe Content:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test cases with safe content that should pass
declare -a safe_tests=(
    "const config = { debug: true };|JavaScript code"
    "SELECT * FROM users WHERE id = 123;|SQL query"
    "echo 'Hello World'|Bash command"
    "apiKey=process.env.API_KEY|Environment variable reference"
    "# This is a comment|Comment"
    "def hello_world():\n    print('Hello')|Python function"
)

for test_case in "${safe_tests[@]}"; do
    IFS='|' read -r content description <<< "$test_case"
    
    echo -n "• Testing ${description}: "
    
    # Run the test
    result=$(echo -e "$content" | node "$HOOKS_DIR/secure-command.js" 2>&1)
    status=$?
    
    # Extract JSON status if available
    json_status=$(echo "$result" | grep -o '"status":\s*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' 2>/dev/null)
    
    if [ $status -eq 0 ] && [ "$json_status" != "danger" ]; then
        echo -e "${GREEN}✅ Passed${NC}"
        ((passed_tests++))
    else
        echo -e "${RED}❌ BLOCKED (This safe content should not be blocked!)${NC}"
        ((failed_tests++))
    fi
done

# Test settings.json configuration
echo
echo -e "${CYAN}Checking Hook Configuration:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${GREEN}✅ Settings file exists${NC}"
    
    # Check for hook configurations
    for hook in "pre-write" "pre-edit" "pre-bash" "pre-commit"; do
        if grep -q "\"$hook\".*secure-command.js" "$SETTINGS_FILE"; then
            echo -e "${GREEN}✅ Hook configured: $hook${NC}"
        else
            echo -e "${YELLOW}⚠️  Hook not configured: $hook${NC}"
        fi
    done
else
    echo -e "${RED}❌ Settings file not found at $SETTINGS_FILE${NC}"
fi

# Summary
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Test Summary:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Tests Passed: ${GREEN}$passed_tests${NC}"
echo -e "Tests Failed: ${RED}$failed_tests${NC}"

if [ $failed_tests -eq 0 ]; then
    echo
    echo -e "${GREEN}🎉 All tests passed! The secrets guardian is working correctly.${NC}"
    echo -e "${GREEN}Your Claude sessions are now protected from accidental secret exposure.${NC}"
    exit 0
else
    echo
    echo -e "${RED}⚠️  Some tests failed. Please check your installation.${NC}"
    echo -e "${YELLOW}Try reinstalling with:${NC}"
    echo "  curl -sSL https://raw.githubusercontent.com/refcell/guardian/main/install.sh | bash"
    exit 1
fi