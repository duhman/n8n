#!/usr/bin/env node

// Test connection to n8n instance
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load environment variables
function loadEnv() {
    const envPath = path.join(__dirname, '.env');
    if (!fs.existsSync(envPath)) {
        console.error('❌ .env file not found');
        process.exit(1);
    }
    
    const envContent = fs.readFileSync(envPath, 'utf8');
    const env = {};
    
    envContent.split('\n').forEach(line => {
        line = line.trim();
        if (line && !line.startsWith('#') && line.includes('=')) {
            const [key, ...valueParts] = line.split('=');
            env[key.trim()] = valueParts.join('=').trim();
        }
    });
    
    return env;
}

async function testConnection() {
    console.log('🔧 Testing n8n MCP Server Connection...\n');
    
    const env = loadEnv();
    const apiUrl = env.N8N_API_URL;
    const apiKey = env.N8N_API_KEY;
    
    if (!apiUrl || !apiKey) {
        console.error('❌ Missing N8N_API_URL or N8N_API_KEY in .env file');
        process.exit(1);
    }
    
    console.log(`🌐 API URL: ${apiUrl}`);
    console.log(`🔑 API Key: ${apiKey.substring(0, 20)}...`);
    console.log('');
    
    // Test 1: Basic API connectivity
    console.log('📡 Test 1: Basic API connectivity...');
    try {
        const response = await fetch(`${apiUrl}/workflows`, {
            method: 'GET',
            headers: {
                'X-N8N-API-KEY': apiKey,
                'Content-Type': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            console.log(`✅ Connected successfully! Found ${data.data?.length || 0} workflows`);
            
            if (data.data && data.data.length > 0) {
                console.log('📋 Sample workflows:');
                data.data.slice(0, 3).forEach((workflow, index) => {
                    console.log(`   ${index + 1}. ${workflow.name} (ID: ${workflow.id})`);
                });
            }
        } else {
            console.error(`❌ API request failed: ${response.status} ${response.statusText}`);
            const errorText = await response.text();
            console.error(`   Error: ${errorText}`);
        }
    } catch (error) {
        console.error(`❌ Connection failed: ${error.message}`);
    }
    
    // Test 2: Check API permissions
    console.log('\n🔐 Test 2: Checking API permissions...');
    try {
        const response = await fetch(`${apiUrl}/credentials`, {
            method: 'GET',
            headers: {
                'X-N8N-API-KEY': apiKey,
                'Content-Type': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            console.log(`✅ Credentials access granted (${data.data?.length || 0} credentials)`);
        } else if (response.status === 403) {
            console.log('⚠️  Limited permissions - credentials access denied (this is normal for some API keys)');
        } else {
            console.error(`❌ Credentials check failed: ${response.status}`);
        }
    } catch (error) {
        console.error(`❌ Permissions check failed: ${error.message}`);
    }
    
    // Test 3: Test workflow execution capability
    console.log('\n▶️  Test 3: Testing execution permissions...');
    try {
        const response = await fetch(`${apiUrl}/executions`, {
            method: 'GET',
            headers: {
                'X-N8N-API-KEY': apiKey,
                'Content-Type': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            console.log(`✅ Execution access granted (${data.data?.length || 0} recent executions)`);
        } else {
            console.error(`❌ Execution access failed: ${response.status}`);
        }
    } catch (error) {
        console.error(`❌ Execution test failed: ${error.message}`);
    }
    
    console.log('\n🎉 Connection test complete!');
    console.log('\n📋 Next steps:');
    console.log('   1. If all tests passed, your MCP server is ready to use');
    console.log('   2. You can now use this server with AI assistants that support MCP');
    console.log('   3. The server can manage workflows, executions, and credentials');
    console.log('\n🚀 To start the MCP server: npm start');
}

testConnection().catch(console.error);