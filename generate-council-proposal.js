#!/usr/bin/env node

const { ApiPromise, WsProvider } = require('@polkadot/api');
const { hexToU8a, u8aToHex } = require('@polkadot/util');

async function generateCouncilProposal(recipient, amountPlanck, threshold = 3, lengthBound = 10000, wsEndpoint = 'wss://wss.api.moonbeam.network') {
    try {
        // Connect to Moonbeam network with specific options
        const wsProvider = new WsProvider(wsEndpoint);
        const api = await ApiPromise.create({ 
            provider: wsProvider,
            throwOnConnect: true,
            noInitWarn: true
        });
        
        console.log('Connected to Moonbeam network');
        console.log(`Recipient: ${recipient}`);
        console.log(`Amount: ${amountPlanck} planck`);
        console.log(`Threshold: ${threshold}`);
        console.log(`Length Bound: ${lengthBound}`);
        console.log('');

        // Wait for API to be ready
        await api.isReady;

        // Create the inner treasury.spend call
        // treasury.spend expects: (assetKind, amount, beneficiary, validFrom)
        const treasuryCall = api.tx.treasury.spend({ Native: null }, amountPlanck, recipient, null);
        const treasuryCallHex = treasuryCall.method.toHex();
        
        console.log('Inner treasury.spend call:');
        console.log(`Call Hash: ${treasuryCall.method.hash.toHex()}`);
        console.log(`Encoded: ${treasuryCallHex}`);
        console.log('');

        // Create the outer council.propose call
        const councilCall = api.tx.treasuryCouncilCollective.propose(threshold, treasuryCall, lengthBound);
        const councilCallHex = councilCall.method.toHex();
        
        console.log('Outer council.propose call:');
        console.log(`Call Hash: ${councilCall.method.hash.toHex()}`);
        console.log(`Encoded: ${councilCallHex}`);
        console.log('');

        // Get the full encoded call hash
        const fullCallHash = councilCall.method.hash.toHex();
        
        console.log('Final Result:');
        console.log(`Full Call Hash: ${fullCallHash}`);
        console.log(`Full Encoded Call: ${councilCallHex}`);
        console.log('');

        // Disconnect
        await api.disconnect();
        
        return {
            treasuryCallHash: treasuryCall.method.hash.toHex(),
            treasuryCallHex: treasuryCallHex,
            councilCallHash: councilCall.method.hash.toHex(),
            councilCallHex: councilCallHex,
            fullCallHash: fullCallHash
        };

    } catch (error) {
        console.error('Error generating council proposal:', error);
        throw error;
    }
}

async function generateMoonriverProposal(recipient, amountPlanck, threshold = 3, lengthBound = 10000, wsEndpoint = 'wss://wss.api.moonriver.moonbeam.network') {
    try {
        // Connect to Moonriver network with specific options
        const wsProvider = new WsProvider(wsEndpoint);
        const api = await ApiPromise.create({ 
            provider: wsProvider,
            throwOnConnect: true,
            noInitWarn: true
        });
        
        console.log('Connected to Moonriver network');
        console.log(`Recipient: ${recipient}`);
        console.log(`Amount: ${amountPlanck} planck`);
        console.log(`Threshold: ${threshold}`);
        console.log(`Length Bound: ${lengthBound}`);
        console.log('');

        // Wait for API to be ready
        await api.isReady;

        // Create the inner treasury.spend call
        // treasury.spend expects: (assetKind, amount, beneficiary, validFrom)
        const treasuryCall = api.tx.treasury.spend({ Native: null }, amountPlanck, recipient, null);
        const treasuryCallHex = treasuryCall.method.toHex();
        
        console.log('Inner treasury.spend call:');
        console.log(`Call Hash: ${treasuryCall.method.hash.toHex()}`);
        console.log(`Encoded: ${treasuryCallHex}`);
        console.log('');

        // Create the outer council.propose call
        const councilCall = api.tx.treasuryCouncilCollective.propose(threshold, treasuryCall, lengthBound);
        const councilCallHex = councilCall.method.toHex();
        
        console.log('Outer council.propose call:');
        console.log(`Call Hash: ${councilCall.method.hash.toHex()}`);
        console.log(`Encoded: ${councilCallHex}`);
        console.log('');

        // Get the full encoded call hash
        const fullCallHash = councilCall.method.hash.toHex();
        
        console.log('Final Result:');
        console.log(`Full Call Hash: ${fullCallHash}`);
        console.log(`Full Encoded Call: ${councilCallHex}`);
        console.log('');

        // Disconnect
        await api.disconnect();
        
        return {
            treasuryCallHash: treasuryCall.method.hash.toHex(),
            treasuryCallHex: treasuryCallHex,
            councilCallHash: councilCall.method.hash.toHex(),
            councilCallHex: councilCallHex,
            fullCallHash: fullCallHash
        };

    } catch (error) {
        console.error('Error generating council proposal:', error);
        throw error;
    }
}

// Main function
async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 3) {
        console.log('Usage: node generate-council-proposal.js <network> <recipient> <amount_planck> [threshold] [length_bound] [ws_endpoint] [proxy_address]');
        console.log('');
        console.log('Arguments:');
        console.log('  network        : "moonbeam" or "moonriver"');
        console.log('  recipient      : Ethereum-style address (0x...)');
        console.log('  amount_planck  : Amount in planck (smallest unit)');
        console.log('  threshold      : Council threshold (default: 3)');
        console.log('  length_bound   : Length bound (default: 10000)');
        console.log('  ws_endpoint    : WebSocket endpoint (optional)');
        console.log('  proxy_address  : Proxy address (optional, if set wraps call in proxy.proxy)');
        console.log('');
        console.log('Examples:');
        console.log('  node generate-council-proposal.js moonbeam 0x1234567890123456789012345678901234567890 1000000000000000000');
        console.log('  node generate-council-proposal.js moonriver 0xabcdefabcdefabcdefabcdefabcdefabcdefabcd 2000000000000000000 5 15000');
        console.log('  node generate-council-proposal.js moonbeam 0x1234567890123456789012345678901234567890 1000000000000000000 3 10000 wss://custom.moonbeam.network');
        console.log('  node generate-council-proposal.js moonbeam 0x1234567890123456789012345678901234567890 1000000000000000000 3 10000 wss://custom.moonbeam.network 0xProxyAddressHere');
        process.exit(1);
    }

    const network = args[0];
    const recipient = args[1];
    const amountPlanck = args[2];
    const threshold = args[3] ? parseInt(args[3]) : 3;
    const lengthBound = args[4] ? parseInt(args[4]) : 10000;
    const wsEndpoint = args[5] || (network === 'moonbeam' ? 'wss://wss.api.moonbeam.network' : 'wss://wss.api.moonriver.moonbeam.network');
    const proxyAddress = args[6];

    // Validate network
    if (network !== 'moonbeam' && network !== 'moonriver') {
        console.error('Error: Network must be "moonbeam" or "moonriver"');
        process.exit(1);
    }

    // Validate recipient address
    if (!recipient.match(/^0x[a-fA-F0-9]{40}$/)) {
        console.error('Error: Recipient must be a valid Ethereum-style address (0x followed by 40 hex characters)');
        process.exit(1);
    }

    // Validate amount
    if (!/^\d+$/.test(amountPlanck)) {
        console.error('Error: Amount must be a positive integer');
        process.exit(1);
    }

    // Validate proxy address if provided
    if (proxyAddress && !proxyAddress.match(/^0x[a-fA-F0-9]{40}$/)) {
        console.error('Error: Proxy address must be a valid Ethereum-style address (0x followed by 40 hex characters)');
        process.exit(1);
    }

    try {
        console.log('=== Council Proposal Generator ===');
        console.log(`Network: ${network}`);
        console.log(`Recipient: ${recipient}`);
        console.log(`Amount: ${amountPlanck} planck`);
        console.log(`Threshold: ${threshold}`);
        console.log(`Length Bound: ${lengthBound}`);
        if (proxyAddress) {
            console.log(`Proxy Address: ${proxyAddress}`);
        }
        console.log('');

        let result, api, wsProvider;
        if (network === 'moonbeam') {
            wsProvider = new WsProvider(wsEndpoint);
            api = await ApiPromise.create({ provider: wsProvider, throwOnConnect: true, noInitWarn: true });
            await api.isReady;
            // treasury.spend expects: (assetKind, amount, beneficiary, validFrom)
            const treasuryCall = api.tx.treasury.spend({ Native: null }, amountPlanck, recipient, null);
            const treasuryCallHex = treasuryCall.method.toHex();
            console.log('Inner treasury.spend call:');
            console.log(`Call Hash: ${treasuryCall.method.hash.toHex()}`);
            console.log(`Encoded: ${treasuryCallHex}`);
            console.log('');
            const councilCall = api.tx.treasuryCouncilCollective.propose(threshold, treasuryCall, lengthBound);
            const councilCallHex = councilCall.method.toHex();
            console.log('Outer council.propose call:');
            console.log(`Call Hash: ${councilCall.method.hash.toHex()}`);
            console.log(`Encoded: ${councilCallHex}`);
            console.log('');
            let fullCallHex = councilCallHex;
            let fullCallHash = councilCall.method.hash.toHex();
            if (proxyAddress) {
                // Wrap in proxy.proxy(proxyAddress, null, councilCall)
                const proxyCall = api.tx.proxy.proxy(proxyAddress, null, councilCall);
                fullCallHex = proxyCall.method.toHex();
                fullCallHash = proxyCall.method.hash.toHex();
                console.log('Proxy-wrapped call:');
                console.log(`Call Hash: ${fullCallHash}`);
                console.log(`Encoded: ${fullCallHex}`);
                console.log('');
            }
            await api.disconnect();
            result = {
                treasuryCallHash: treasuryCall.method.hash.toHex(),
                treasuryCallHex: treasuryCallHex,
                councilCallHash: councilCall.method.hash.toHex(),
                councilCallHex: councilCallHex,
                fullCallHash: fullCallHash,
                fullCallHex: fullCallHex,
                isProxy: !!proxyAddress
            };
        } else {
            wsProvider = new WsProvider(wsEndpoint);
            api = await ApiPromise.create({ provider: wsProvider, throwOnConnect: true, noInitWarn: true });
            await api.isReady;
            const treasuryCall = api.tx.treasury.spend({ Native: null }, amountPlanck, recipient, null);
            const treasuryCallHex = treasuryCall.method.toHex();
            console.log('Inner treasury.spend call:');
            console.log(`Call Hash: ${treasuryCall.method.hash.toHex()}`);
            console.log(`Encoded: ${treasuryCallHex}`);
            console.log('');
            const councilCall = api.tx.treasuryCouncilCollective.propose(threshold, treasuryCall, lengthBound);
            const councilCallHex = councilCall.method.toHex();
            console.log('Outer council.propose call:');
            console.log(`Call Hash: ${councilCall.method.hash.toHex()}`);
            console.log(`Encoded: ${councilCallHex}`);
            console.log('');
            let fullCallHex = councilCallHex;
            let fullCallHash = councilCall.method.hash.toHex();
            if (proxyAddress) {
                // Wrap in proxy.proxy(proxyAddress, null, councilCall)
                const proxyCall = api.tx.proxy.proxy(proxyAddress, null, councilCall);
                fullCallHex = proxyCall.method.toHex();
                fullCallHash = proxyCall.method.hash.toHex();
                console.log('Proxy-wrapped call:');
                console.log(`Call Hash: ${fullCallHash}`);
                console.log(`Encoded: ${fullCallHex}`);
                console.log('');
            }
            await api.disconnect();
            result = {
                treasuryCallHash: treasuryCall.method.hash.toHex(),
                treasuryCallHex: treasuryCallHex,
                councilCallHash: councilCall.method.hash.toHex(),
                councilCallHex: councilCallHex,
                fullCallHash: fullCallHash,
                fullCallHex: fullCallHex,
                isProxy: !!proxyAddress
            };
        }

        console.log('=== Summary ===');
        console.log(`Network: ${network}`);
        console.log(`Treasury Call Hash: ${result.treasuryCallHash}`);
        console.log(`Council Call Hash: ${result.councilCallHash}`);
        if (result.isProxy) {
            console.log('Full Encoded Call (Proxy):');
            console.log(result.fullCallHex);
        } else {
            console.log('Full Encoded Call:');
            console.log(result.fullCallHex);
        }
        console.log('');
        console.log('Copy the "Full Encoded Call" above and use it in Polkadot.js Apps');

    } catch (error) {
        console.error('Failed to generate council proposal:', error.message);
        process.exit(1);
    }
}

// Run the script
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { generateCouncilProposal, generateMoonriverProposal }; 