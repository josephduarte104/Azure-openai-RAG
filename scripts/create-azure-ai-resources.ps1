# Introduction to RAG with Azure OpenAI

## Create Azure AI Search resource

$rgName = "rg-openai-rag-swc-dev"
$aiSearchName = "ai-search-swc-course-01"
$aiServiceName = "ai-services-swc-course"
$location = "eastus2"

# Using Mac 
export RG_NAME="rg-openai-rag-swc-dev"
export AI_SEARCH_NAME="ai-search-swc-course-01"
export AI_SERVICE_NAME="ai-services-swc-course"
export LOCATION="eastus2"

### 1. Create a resource group

az group create -n $rgName -l $location

# Mac

az group create -n $RG_NAME -l $LOCATION

### 2. Create a search service

az search service create -n $AI_SEARCH_NAME -g $RG_NAME --sku "Standard"

### 3. Get the admin key

az search admin-key show --service-name $AI_SEARCH_NAME -g $RG_NAME
# {
#   "primaryKey": "4wIdp9wU2xwTM5ltGro4wNF1VPXwPcrrHMuoy47CYeAzSxxxxxxxx",
#   "secondaryKey": "oa1LM4JA47W4lby8wa8cfOvBKif8I4CidFMTHG71yPAzxxxxxxx"
# }

## Create an Azure AI Services resource

az cognitiveservices account create -n $AI_SERVICE_NAME -g $RG_NAME --kind AIServices --sku S0 --location $LOCATION

### Get the endpoint URL, Keys and resource ID

az cognitiveservices account show -n $AI_SERVICE_NAME -g $RG_NAME --query properties.endpoint
# "https://swedencentral.api.cognitive.microsoft.com/"

az cognitiveservices account keys list -n $AI_SERVICE_NAME -g $RG_NAME
# {
#   "key1": "78f5592e1f70494dabd1a4040a61a96a",
#   "key2": "4f23266a2eb0475c8a0112044e03c4d1"
# }

az cognitiveservices account show -n $AI_SERVICE_NAME -g $RG_NAME --query id
# "/subscriptions/38977b70-47bf-4da5-a492-xxxxxxxxx/resourceGroups/rg-openai-course2/providers/Microsoft.CognitiveServices/accounts/ai-services-swc-demo"

## Creating deployment for ChatGPT 4o model

az cognitiveservices account deployment create -n $AI_SERVICE_NAME -g $RG_NAME \
    --deployment-name gpt-4o \
    --model-name gpt-4o \
    --model-version "2024-05-13" \
    --model-format OpenAI \
    --sku-capacity "150" \
    --sku-name "GlobalStandard"

## Creating an embedding model deployment

az cognitiveservices account deployment create -n $AI_SERVICE_NAME -g $RG_NAME \
    --deployment-name text-embedding-3-large \
    --model-name text-embedding-3-large \
    --model-version "1" \
    --model-format OpenAI \
    --sku-capacity "120" \
    --sku-name "Standard"

## Create a Hub and Project

### Create a Hub

az ml workspace create --kind hub -g $RG_NAME -n hub-demo

### Create a Project

HUB_ID=$(az ml workspace show -g $RG_NAME -n hub-demo --query id -o tsv)

az ml workspace create --kind project --hub-id $HUB_ID -g $RG_NAME -n project-demo

# View the connection details

az cognitiveservices account show -n $AI_SERVICE_NAME -g $RG_NAME --query properties.endpoint
az cognitiveservices account keys list -n $AI_SERVICE_NAME -g $RG_NAME
az cognitiveservices account show -n $AI_SERVICE_NAME -g $RG_NAME --query id

## Create a connection.yml file to connect AI Services to the Hub

$endpoint=$(az cognitiveservices account show -n $aiServiceName -g $rgName --query properties.endpoint)
$api_key=$(az cognitiveservices account keys list -n $aiServiceName -g $rgName --query key1)
$ai_services_resource_id=$(az cognitiveservices account show -n $aiServiceName -g $rgName --query id)

@"
name: ai-service-connection
type: azure_ai_services
endpoint: $endpoint
api_key: $api_key
ai_services_resource_id: $ai_services_resource_id
"@ > connection.yml

az ml connection create --file connection.yml -g $RG_NAME --workspace-name hub-demo