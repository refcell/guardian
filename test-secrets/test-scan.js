const fs = require('fs');
const path = require('path');

const CONFIG_FILE = path.join(process.env.HOME, '.claude', 'hooks', 'secrets-guardian.json');

// Load patterns
let patterns = {};
try {
    const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
    for (const [category, pats] of Object.entries(config.patterns || {})) {
        patterns[category] = pats.map(p => {
            try {
                return new RegExp(p, 'gmi');
            } catch (e) {
                return null;
            }
        }).filter(p => p !== null);
    }
} catch (e) {
    console.log('Error loading config:', e.message);
}

console.log('Loaded', Object.keys(patterns).length, 'pattern categories');

// Test on .env content
const content = fs.readFileSync('.env', 'utf8');
console.log('Testing content:', content);

let found = 0;
for (const [category, pats] of Object.entries(patterns)) {
    for (const pattern of pats) {
        pattern.lastIndex = 0;
        const matches = [...content.matchAll(pattern)];
        if (matches.length > 0) {
            console.log(`Found ${category}:`, matches.map(m => m[0]));
            found += matches.length;
        }
    }
}

console.log('Total secrets found:', found);