# Construction Safety and Building Code Enforcement Platform

A comprehensive blockchain-based platform for managing construction safety, building permits, inspections, and compliance tracking using Stacks blockchain and Clarity smart contracts.

## Overview

This platform consists of five interconnected smart contracts that manage the entire construction lifecycle from permit application to occupancy certification:

1. **Building Permit Compliance** - Tracks permit applications and compliance status
2. **Safety Inspection Scheduling** - Manages inspection scheduling and results
3. **Worker Safety Incident Reporting** - Records and tracks safety incidents
4. **Materials Quality Verification** - Ensures materials meet specifications
5. **Occupancy Permit Issuance** - Final certification for building occupancy

## Smart Contracts

### 1. Building Permit Compliance (`building-permit-compliance.clar`)
- Manages permit applications and approvals
- Tracks compliance with approved building plans
- Handles permit modifications and renewals
- Maintains permit status throughout construction

### 2. Safety Inspection Scheduling (`safety-inspection-scheduling.clar`)
- Schedules required inspections at construction phases
- Records inspection results and compliance status
- Manages inspector assignments and availability
- Tracks inspection history and follow-ups

### 3. Worker Safety Incident Reporting (`worker-safety-incident-reporting.clar`)
- Records workplace accidents and incidents
- Tracks safety violations and corrective actions
- Maintains safety statistics and trends
- Implements prevention measures and training requirements

### 4. Materials Quality Verification (`materials-quality-verification.clar`)
- Verifies building materials meet specifications
- Tracks material certifications and test results
- Manages supplier compliance and ratings
- Records material usage and inventory

### 5. Occupancy Permit Issuance (`occupancy-permit-issuance.clar`)
- Issues final occupancy certificates
- Verifies all safety and compliance requirements
- Manages certificate renewals and modifications
- Tracks building occupancy status

## Key Features

- **Immutable Records**: All permits, inspections, and incidents are permanently recorded
- **Transparency**: Public access to safety records and compliance status
- **Automated Compliance**: Smart contract logic enforces regulatory requirements
- **Real-time Tracking**: Live updates on construction progress and safety status
- **Audit Trail**: Complete history of all construction activities

## Data Structures

### Permit Structure
- Permit ID, applicant, property address
- Construction type, estimated completion
- Approval status, compliance score
- Associated inspections and incidents

### Inspection Structure
- Inspection ID, permit reference, inspector
- Inspection type, scheduled/completed dates
- Results, violations found, follow-up required

### Incident Structure
- Incident ID, permit reference, reporter
- Incident type, severity level, description
- Corrective actions, prevention measures

### Material Structure
- Material ID, supplier, specifications
- Quality certifications, test results
- Usage tracking, compliance status

### Occupancy Certificate Structure
- Certificate ID, building reference
- Safety compliance verification
- Occupancy limits, special conditions
- Issuance and expiration dates

## Usage

1. **Apply for Building Permit**: Submit construction plans and requirements
2. **Schedule Inspections**: Coordinate required safety inspections
3. **Report Incidents**: Document any safety incidents or violations
4. **Verify Materials**: Ensure all materials meet quality standards
5. **Issue Occupancy Permit**: Final certification for building use

## Testing

Run the test suite with:
\`\`\`bash
npm test
\`\`\`

## Deployment

Deploy contracts using Clarinet:
\`\`\`bash
clarinet deploy
\`\`\`

## Security Considerations

- Only authorized personnel can approve permits and inspections
- Incident reports are immutable once submitted
- Material certifications require verified supplier signatures
- Occupancy permits require all safety checks to pass

## Compliance Standards

The platform enforces compliance with:
- Local building codes and regulations
- OSHA safety requirements
- Material quality standards
- Environmental regulations
- Accessibility requirements
