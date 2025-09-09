#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { TenzirPlatformStack } from '../lib/tenzir-platform-stack';

const app = new cdk.App();

// Get context parameters
const domainName = app.node.tryGetContext('domainName') || app.node.tryGetContext('domain-name');
const randomSubdomain = app.node.tryGetContext('randomSubdomain') || app.node.tryGetContext('random-subdomain') || 'false';
const trustingRoleArn = app.node.tryGetContext('trustingRoleArn') || app.node.tryGetContext('trusting-role-arn');

if (!domainName) {
  throw new Error('domainName context parameter is required. Use: cdk deploy -c domainName=example.org');
}

if (!trustingRoleArn) {
  throw new Error('trustingRoleArn context parameter is required. Use: cdk deploy -c trustingRoleArn=arn:aws:iam::123456789012:role/TrustingRole');
}

new TenzirPlatformStack(app, 'TenzirPlatformStack', {
  env: {
    account: '123456789012', // Placeholder for synthesis
    region: 'eu-west-1',
  },
  domainName,
  randomSubdomain: randomSubdomain === 'true',
  trustingRoleArn,
});