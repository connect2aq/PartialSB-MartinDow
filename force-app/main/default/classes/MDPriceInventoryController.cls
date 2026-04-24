public with sharing class MDPriceInventoryController {
    // --- API Response Wrapper Classes ---
    public class PriceApiResponse {
        public Boolean success;
        public String message;
        public PriceData data;
    }
    public class InventoryApiResponse {
        public Boolean success;
        public String message;
        public List<InventoryData> data;
    }

    // Move data classes to top-level
    public class PriceData {
        public String materialNo;
        public String salesOrg;
        public String distributionChannel;
        public Decimal amount;
        public String currencycode;
        public String uom;
        public String validFrom;
        public String validTo;
    }

    public class InventoryData {
        public String materialNumber;
        public String materialDescription;
        public String plant;
        public Decimal totalAvailableStock;
        public Decimal totalBlockedStock;
        public Decimal totalAllocatedStock;
        public Decimal totalRestrictedStock;
        public List<SupplierBatch> supplierBatch;
    }

    public class SupplierBatch {
        @AuraEnabled
        public String storageLocation;
        @AuraEnabled
        public Decimal availableStock;
        @AuraEnabled
        public Decimal blockedStock;
        @AuraEnabled
        public Decimal allocatedStock;
        @AuraEnabled
        public Decimal restrictedStock;
        
        @AuraEnabled
        public List<Batches> batches;
        
    }

    public class Batches
    {
        @AuraEnabled
        public String supplierBatch{get;set; }
        @AuraEnabled
        public String batch{get;set; }
        @AuraEnabled
        public String expiryDate{get;set; }
        @AuraEnabled
        public Decimal availableStock{get;set; }
        @AuraEnabled
        public Decimal allocatedStock{get;set; }
        @AuraEnabled
        public List<BatchAllocation> allocations{get;set; }
    }

    public class BatchAllocation
    {
        @AuraEnabled
        public String so{get;set;   }
        @AuraEnabled
        public String customer{get;set;   }
        @AuraEnabled
        public String name{get;set;   }
        @AuraEnabled
        public Decimal allocatedStock{get;set;   }
    }

    @AuraEnabled
    public static MaterialPriceInventoryWrapper getLatestPriceInventory(
        Id materialId,
        String materialNumberParam
    ) {
        InventoryApiResponse invResp = null;
        TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
        String accessToken = (tokenResult != null) ? tokenResult.token : null;
        String baseEndpointUrl = (tokenResult != null)
            ? tokenResult.baseEndpointUrl
            : null;
        String apiStatus;
        String apiError = null;
        String currencyIsoCode;
        String priceUoM;
        DateTime validFrom;
        DateTime validTo;
        Decimal inventoryQty;
        Decimal availableStock;
        Decimal restrictedStock;
        Decimal blockedStock;
        Decimal allocatedStock;
        String plant;
        String storageLocation;
        String batch;

        System.debug('aq access token: ' + accessToken);
        System.debug('aq base endpoint URL: ' + baseEndpointUrl);
        System.debug(
            'aq material number: ' + String.valueOf(materialNumberParam)
        );

        if (String.isBlank(accessToken) || String.isBlank(baseEndpointUrl)) {
            apiStatus = 'Error';
            apiError = 'Failed to get access token or endpoint URL';
        } else {
            try {

                // --- Inventory API ---
                System.debug('>>>>baseEndpointUrl: '+ JSON.serialize(baseEndpointUrl)  );
                HttpRequest invReq = new HttpRequest();
                invReq.setMethod('GET');
                invReq.setEndpoint(
                    baseEndpointUrl +
                        'SAP/GetMaterialInventoryv3?MaterialNumber=' +
                        String.valueOf(materialNumberParam)
                );
                invReq.setHeader('Authorization', 'Bearer ' + accessToken);
                invReq.setTimeout(60000);
                System.debug('>>>>invReq baseendpoint URL: '+ baseEndpointUrl);
                System.debug('>>>>invReq endpoint: '+ invReq.getEndpoint());
                System.debug('>>>>invReq method: '+ invReq.getMethod());
                System.debug('>>>>invReq header: '+ invReq.getHeader('Authorization'));

                Http http = new Http();
                HttpResponse invRes = http.send(invReq);

                ApiLogUtil.get().add(
                    'GetMaterialInventoryv3', 
                    baseEndpointUrl + 'SAP/GetMaterialInventoryv3?MaterialNumber=' + String.valueOf(materialNumberParam), 
                    'GET', null, invRes.getStatusCode(), invRes.getBody()
                );

                System.debug('>>>>invRes Status: '+ invRes.getStatusCode() );
                System.debug('>>>>invRes Body: '+ invRes.getBody() );
                List<InventoryData> listofinventorydata = new List<InventoryData>();
                if (invRes.getStatusCode() == 200) {
                    invResp = (InventoryApiResponse) JSON.deserialize(
                        invRes.getBody(),
                        InventoryApiResponse.class
                    );
                    System.debug('>>>>invResp Model: '+ invResp );
                    if (invResp != null && invResp.success) 
                    {
                         System.debug('>>>>invResp Data Model: '+ invResp.data);
                        InventoryData invData = invResp.data[0];
                        System.debug('>>>>invData Data Model: '+ invResp.data[0]);
                        inventoryQty = invData != null &&
                            invData.totalAvailableStock != null
                            ? invData.totalAvailableStock
                            : null;
                        availableStock = invData != null &&
                            invData.totalAvailableStock != null
                            ? invData.totalAvailableStock
                            : null;
                        blockedStock = invData != null &&
                            invData.totalBlockedStock != null
                            ? invData.totalBlockedStock
                            : null;
                        allocatedStock = invData != null &&
                            invData.totalAllocatedStock != null
                            ? invData.totalAllocatedStock
                            : null;
                        restrictedStock = invData != null &&
                            invData.totalRestrictedStock != null
                            ? invData.totalRestrictedStock
                            : null;
                        plant = invData != null ? invData.plant : null;
                        // storageLocation and batch are now per-supplierBatch, not top-level
                        storageLocation = null;
                        batch = null;
                    } 
                    else 
                    {
                        apiStatus = 'Error';
                        apiError =
                            (apiError != null ? apiError + '; ' : '') +
                            'Inventory API: ' +
                            (invResp != null ? invResp.message : 'No response');
                    }
                } else {
                    apiStatus = 'Error';
                    apiError =
                        (apiError != null ? apiError + '; ' : '') +
                        'Inventory API HTTP: ' +
                        invRes.getStatus();
                }
            } catch (Exception ex) {
                apiStatus = 'Error';
                apiError =
                    (apiError != null ? apiError + '; ' : '') + ex.getMessage();
            } finally {
                ApiLogUtil.get().flushSync();
            }
        }

        // No need to create a record, just use local variables

        System.debug('Returning MaterialPriceInventoryWrapper with values:');
        System.debug('  currencyIsoCode=' + String.valueOf(currencyIsoCode));
        System.debug('  priceUoM=' + String.valueOf(priceUoM));
        System.debug('  priceValidFrom=' + String.valueOf(validFrom));
        System.debug('  priceValidTo=' + String.valueOf(validTo));
        System.debug('  inventoryQty=' + String.valueOf(inventoryQty));
        System.debug(
            '  inventoryAvailableStock=' + String.valueOf(availableStock)
        );
        System.debug(
            '  inventoryRestrictedStock=' + String.valueOf(restrictedStock)
        );
        System.debug('  inventoryBlockedStock=' + String.valueOf(blockedStock));
        System.debug(
            '  inventoryAllocatedStock=' + String.valueOf(allocatedStock)
        );
        System.debug('  inventoryPlant=' + String.valueOf(plant));
        System.debug(
            '  inventoryStorageLocation=' + String.valueOf(storageLocation)
        );
        System.debug('  inventoryBatch=' + String.valueOf(batch));
        System.debug('  lastUpdated=' + String.valueOf(Datetime.now()));
        System.debug('  apiStatus=' + String.valueOf(apiStatus));
        System.debug('  apiError=' + String.valueOf(apiError));
        // Find the invData object if available
        List<SupplierBatch> supplierBatchList = (invResp != null &&
            invResp.success &&
            invResp.data != null)
            ? invResp.data[0].supplierBatch
            : new List<SupplierBatch>();

        System.debug(' Supplier Batch List=' + supplierBatchList);
        
        return new MaterialPriceInventoryWrapper(
            currencyIsoCode,
            priceUoM,
            validFrom,
            validTo,
            inventoryQty,
            availableStock,
            restrictedStock,
            blockedStock,
            allocatedStock,
            plant,
            storageLocation,
            batch,
            Datetime.now(),
            apiStatus,
            apiError,
            supplierBatchList
        );
    }

    public class MaterialPriceInventoryWrapper {
        @AuraEnabled
        public String currencyIsoCode;
        @AuraEnabled
        public String priceUoM;
        @AuraEnabled
        public Datetime priceValidFrom;
        @AuraEnabled
        public Datetime priceValidTo;
        @AuraEnabled
        public Decimal inventoryQty;
        @AuraEnabled
        public Decimal inventoryAvailableStock;
        @AuraEnabled
        public Decimal inventoryBlockedStock;
        @AuraEnabled
        public Decimal inventoryAllocatedStock;
        @AuraEnabled
        public Decimal inventoryRestrictedStock;
        @AuraEnabled
        public String inventoryPlant;
        @AuraEnabled
        public String inventoryStorageLocation;
        @AuraEnabled
        public String inventoryBatch;
        @AuraEnabled
        public Datetime lastUpdated;
        @AuraEnabled
        public String apiStatus;
        @AuraEnabled
        public String apiError;
        @AuraEnabled
        public List<SupplierBatch> supplierBatch;

        public MaterialPriceInventoryWrapper(
            String currencyIsoCode,
            String priceUoM,
            Datetime priceValidFrom,
            Datetime priceValidTo,
            Decimal inventoryQty,
            Decimal inventoryAvailableStock,
            Decimal inventoryRestrictedStock,
            Decimal inventoryBlockedStock,
            Decimal inventoryAllocatedStock,
            String inventoryPlant,
            String inventoryStorageLocation,
            String inventoryBatch,
            Datetime lastUpdated,
            String apiStatus,
            String apiError,
            List<SupplierBatch> supplierBatch
        ) {
            this.currencyIsoCode = currencyIsoCode;
            this.priceUoM = priceUoM;
            this.priceValidFrom = priceValidFrom;
            this.priceValidTo = priceValidTo;
            this.inventoryQty = inventoryQty;
            this.inventoryAvailableStock = inventoryAvailableStock;
            this.inventoryRestrictedStock = inventoryRestrictedStock;
            this.inventoryBlockedStock = inventoryBlockedStock;
            this.inventoryAllocatedStock = inventoryAllocatedStock;
            this.inventoryPlant = inventoryPlant;
            this.inventoryStorageLocation = inventoryStorageLocation;
            this.inventoryBatch = inventoryBatch;
            this.lastUpdated = lastUpdated;
            this.apiStatus = apiStatus;
            this.apiError = apiError;
            this.supplierBatch = supplierBatch;
        }
    }
}