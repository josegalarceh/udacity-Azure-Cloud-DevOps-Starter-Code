#!/bin/bash
export ARM_SKIP_PROVIDER_REGISTRATION=true
export ARM_CLIENT_ID=<remplace with the Client ID>
export ARM_CLIENT_SECRET=<remplace with the Client secret>
export ARM_SUBSCRIPTION_ID=<remplace with the subscription ID>
export ARM_TENANT_ID=<remplace with the Tenant ID>
ls -la
env | grep ARM