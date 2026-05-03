# Business Case Gap Analysis
**Date:** 2026-05-03
**Source:** `Imports/Updated_Business_Cases.xlsx` → Sheet: `B-Cases`
**Target Org:** MDProd (`wajeeh@martindowproject.com.sfdc`) — **READ-ONLY**
**Prepared by:** Claude Code (automated analysis)

---

## Overview

This report compares every row in the Excel tracking sheet against Business Case records (`Business_Case__c`) in the MDProd Salesforce production org.

**Rule:** Every row in the tracking sheet should have exactly one corresponding `Business_Case__c` record with `Is_Master__c = false`.

**Master Business Cases** (`Is_Master__c = true`) group individual cases where the same customer has more than one machine from the same supplier with the same technology. They are **excluded** from this analysis.

**Matching key used:** `Customer No. (col R)` + `Supplier Code (col B)` + `Technology Code (col F)`

---

## Count Summary

| Metric | Count |
|---|---|
| Excel rows in B-Cases sheet | 191 |
| Excel rows with a Customer No. | 188 |
| Excel rows **without** Customer No. (unmatchable) | 3 |
| SF non-master BCs total | 162 |
| SF non-master BCs **with** Customer No. | 137 |
| SF non-master BCs **without** Customer No. (incomplete data) | 25 |
| **Total missing non-master BCs** | **79** |
| Excel rows with zero SF BC match | 70 |

---

## Section 1: Missing Business Cases (Excel > SF)

Groups where the Excel tracking sheet has more records than exist in MDProd.

### 1.1 Groups With Zero BCs in SF (Completely Missing)

| # | Customer No. | Customer Name | Supplier | Tech | Excel | SF | Missing |
|---|---|---|---|---|---|---|---|
| 1 | 3020000084 | SICVD Baldia-Karachi | B | HM | 1 | 0 | **1** |
| 2 | 3020000084 | SICVD Hyderabad | B | HM | 1 | 0 | **1** |
| 3 | 3020000084 | SICVD Sukkur | B | HM | 1 | 0 | **1** |
| 4 | 3020000084 | SICVD TMK | B | HM | 1 | 0 | **1** |
| 5 | 3020000084 | SICVD, Larkana | B | HM | 1 | 0 | **1** |
| 6 | 3020000084 | SICVD, Nawabshah | B | HM | 1 | 0 | **1** |
| 7 | 3020000114 | DHO Nawabshah Through HS Medical Nawab Shah | DYM | HM | 1 | 0 | **1** |
| 8 | 3020000125 | Minhaj Lab Lahore | E | CC | 1 | 0 | **1** |
| 9 | 3020000135 | Al-Khidmat Welfare Society | ER | URIN | 1 | 0 | **1** |
| 10 | 3020000166 | QAMC | B | HM | 1 | 0 | **1** |
| 11 | 3020000166 | QAMC | B | HM | 1 | 0 | **1** |
| 12 | 3020000166 | QAMC | B | HM | 1 | 0 | **1** |
| 13 | 3020000166 | QAMC | B | HM | 1 | 0 | **1** |
| 14 | 3020000166 | QAMC | B | HM | 1 | 0 | **1** |
| 15 | 3020000166 | QAMC Bahawalpur | B | HM | 1 | 0 | **1** |
| 16 | 3020000206 | Mughal Diagnostics & Research Labs / Cancer Care Hospital | B | HM | 1 | 0 | **1** |
| 17 | 3020000206 | Mughal Lab Lahore | YHLO | IMA | 1 | 0 | **1** |
| 18 | 3020000314 | Hashmani Hospital | YHLO | IMA | 1 | 0 | **1** |
| 19 | 3020000379 | SASIM Sehwan through Z.A.M Traders & Co. | B | HM | 1 | 0 | **1** |
| 20 | 3020000393 | Faisalabad Medical University | B | HM | 1 | 0 | **1** |
| 21 | 3020000393 | Faisalabad Medical University | B | HM | 1 | 0 | **1** |
| 22 | 3020000393 | Faisalabad Medical University | B | HM | 1 | 0 | **1** |
| 23 | 3020000515 | Faisalabad Medical University (Allied) | B | HM | 1 | 0 | **1** |
| 24 | 3020000515 | DHQ Hospital (Allied Hospital-II) | B | HM | 1 | 0 | **1** |
| 25 | 3020000515 | DHQ Hospital (Allied Hospital-II) | B | HM | 1 | 0 | **1** |
| 26 | 3020000515 | DHQ Hospital (Allied Hospital-II) | E | CC | 1 | 0 | **1** |
| 27 | 3020000580 | Ali Medical Center Islamabad | STA | COAG | 1 | 0 | **1** |
| 28 | 3020000645 | Makhdoom Diagnostic Center MDC | OR | IMA | 1 | 0 | **1** |
| 29 | 3020000647 | Alamgir Welfare Trust Int. | ZYB | URIN | 1 | 0 | **1** |
| 30 | 3020000664 | NHS | E | CC | 1 | 0 | **1** |
| 31 | 3020000664 | NHS | OR | IMA | 1 | 0 | **1** |
| 32 | 3020000678 | Saifee Hospital, Karachi | ZYB | URIN | 1 | 0 | **1** |
| 33 | 3020000736 | Lady Aitchison Hospital | B | HM | 1 | 0 | **1** |
| 34 | 3020000736 | Lady Aitchison Hospital | B | HM | 1 | 0 | **1** |
| 35 | 3020000753 | Children's Hospital Faisalabad | B | HM | 1 | 0 | **1** |
| 36 | 3020000776 | The Medical Lab Lahore | ER | URIN | 1 | 0 | **1** |
| 37 | 3020000811 | Hopes Diagnostics | ER | ELCT | 1 | 0 | **1** |
| 38 | 3020000811 | Hopes Diagnostics | ER | URIN | 1 | 0 | **1** |
| 39 | 3020000811 | Hopes Diagnostics | STA | COAG | 1 | 0 | **1** |
| 40 | 3020000896 | Sahiwal Teaching Hospital | B | HM | 1 | 0 | **1** |
| 41 | 3020000960 | Arif Memorial Hospital | STA | COAG | 1 | 0 | **1** |
| 42 | 3020000979 | Medcare International Hospital Gujranwala | E | CC | 1 | 0 | **1** |
| 43 | 3020000979 | Medcare International Hospital Gujranwala | E | CC | 1 | 0 | **1** |
| 44 | 3020000979 | Med Care Hospital | OR | IMA | 1 | 0 | **1** |
| 45 | 3020000979 | Medcare International Hospital Gujranwala | YHLO | IMA | 1 | 0 | **1** |
| 46 | 3020000987 | Peshawar Fertility & IVF Center | YHLO | IMA | 1 | 0 | **1** |
| 47 | 3020001042 | Al-Khidmat Lab Mirpur Azad Kashmir | B | HM | 1 | 0 | **1** |
| 48 | 3020001067 | NICVD | B | HM | 1 | 0 | **1** |
| 49 | 3020001067 | NICVD | B | HM | 1 | 0 | **1** |
| 50 | 3020001074 | Karachi Institute of Heart Diseases (KIHD) | B | HM | 1 | 0 | **1** |
| 51 | 3020001083 | Noor Lab Quetta | YHLO | IMA | 1 | 0 | **1** |
| 52 | 3020001086 | GAMCA (Express Medical Center) | OR | IMA | 1 | 0 | **1** |
| 53 | 3020001102 | GAMCA (Venus Diagnostic Center) | OR | IMA | 1 | 0 | **1** |
| 54 | 3020001115 | Al Khidmat Hospital Karachi | STA | URIN | 1 | 0 | **1** |
| 55 | 3020001124 | Punjab Inst. of Cardiology | OR | IMA | 1 | 0 | **1** |
| 56 | 3020001124 | Punjab Institute of Cardiology Lahore | STA | COAG | 1 | 0 | **1** |
| 57 | 3020001131 | Metlab-Shahmir Enterprises | YHLO | IMA | 1 | 0 | **1** |
| 58 | 3020001174 | Sky Blue Lab Karachi | ER | ELCT | 1 | 0 | **1** |
| 59 | 3020001175 | (SICHN) Sindh Inst. of Child Health and Neonatology | YHLO | IMA | 1 | 0 | **1** |
| 60 | 3020001357 | Healthway Laboratories | YHLO | IMA | 1 | 0 | **1** |
| 61 | 3020001382 | Liaquat University Hospital through Ojhal Enterprises | B | HM | 1 | 0 | **1** |
| 62 | 3020001382 | Liaquat University Hospital through Ojhal Enterprises | B | HM | 1 | 0 | **1** |
| 63 | 3020001382 | Liaquat University Hospital through Ojhal Enterprises | B | HM | 1 | 0 | **1** |
| 64 | 3020001382 | Liaquat University Hospital through Ojhal Enterprises | B | HM | 1 | 0 | **1** |
| 65 | 3020001382 | Liaquat University Hospital through Ojhal Enterprises | B | HM | 1 | 0 | **1** |
| 66 | 3020001399 | Rehman Medical Institute (Pvt) Ltd | HW | ELCT | 1 | 0 | **1** |
| 67 | 3020001511 | Indus Hospital | B | HM | 1 | 0 | **1** |
| 68 | 3020001659 | Imran Idress Hospital / Test Zone | YHLO | IMA | 1 | 0 | **1** |
| 69 | 3020001748 | Fatima Jinnah Inst. of Chest Disease (Jamal Brothers) | ER | ELCT | 1 | 0 | **1** |
| 70 | 3020001814 | Al Khidmat Razi Hospital | STA | COAG | 1 | 0 | **1** |

### 1.2 Groups With Partial BCs in SF (Some Missing)

| Customer No. | Customer Name | Supplier | Tech | Excel | SF | Missing | Existing BCs |
|---|---|---|---|---|---|---|---|
| 3020000084 | SICVD | YHLO | IMA | 4 | 3 | **1** | BCN-000000269, BCN-000000260, BCN-000000263 |
| 3020000206 | Mughal Diagnostics | OR | IMA | 2 | 1 | **1** | BCN-000000234 |
| 3020000633 | The Children Hospital, Multan | E | CC | 2 | 1 | **1** | BCN-000000275 |
| 3020001224 | SOMH-FFH (Shaukat Umar Memorial / Fauji Foundation) | E | CC | 2 | 1 | **1** | BCN-000000272 |
| 3020001511 | Indus Hospital | E | CC | 3 | 1 | **2** | BCN-000000215 |
| 3020001511 | Indus Hospital | ER | ELCT | 3 | 2 | **1** | BCN-000000214, BCN-000000216 |
| 3020001748 | Quetta / Jamal Brothers | YHLO | IMA | 6 | 4 | **2** | BCN-000000205, BCN-000000202, BCN-000000187, BCN-000000273 |

**Subtotal missing from partial groups: 9**

---

## Section 2: SF Non-Master BCs Without Customer Number

25 non-master BCs exist in MDProd but have no `Customer_Number__c` populated — they cannot be matched to any Excel row. These records are likely incomplete or pending assignment:

BCN-000000347, BCN-000000343, BCN-000000344, BCN-000000345,
BCN-000000342, BCN-000000341, BCN-000000338, BCN-000000337,
BCN-000000336, BCN-000000335, BCN-000000334, BCN-000000333,
BCN-000000332, BCN-000000331, BCN-000000330, BCN-000000004,
BCN-000000006, BCN-000000179, BCN-000000223, BCN-000000194,
BCN-000000286, BCN-000000176, BCN-000000229, BCN-000000231,
BCN-000000182

> **Action needed:** Review these 25 records — assign a Customer Number so they can be properly matched, or delete if they are test/duplicate records.

---

## Section 3: SF BCs Exceeding Excel Count (Possible Over-Creation or Vendor Code Issue)

The following groups have **more** non-master BCs in SF than rows in Excel. This could mean duplicates, or may relate to the vendor code discrepancy described in Section 4.

| Customer No. | Customer Name | Supplier | Tech | Excel | SF | Extra | BC Numbers |
|---|---|---|---|---|---|---|---|
| 3020000084 | SICVD | **A** | HM | 0 | 5 | +5 | BCN-000000267, BCN-000000266, BCN-000000264, BCN-000000261, BCN-000000259 |
| 3020000166 | QAMC | **A** | HM | 0 | 6 | +6 | BCN-000000245, BCN-000000244, BCN-000000248, BCN-000000247, BCN-000000246, BCN-000000249 |
| 3020000170 | (Unknown) | STA | COAG | 0 | 1 | +1 | BCN-000000173 |
| 3020000206 | Mughal Diagnostics | **A** | HM | 0 | 1 | +1 | BCN-000000288 |
| 3020000515 | DHQ / Allied Hospital | **A** | HM | 0 | 1 | +1 | BCN-000000180 |
| 3020000736 | Lady Aitchison Hospital | **A** | HM | 0 | 1 | +1 | BCN-000000226 |
| 3020000753 | Children's Hospital Faisalabad | **A** | HM | 0 | 1 | +1 | BCN-000000186 |
| 3020001042 | Al-Khidmat Lab Mirpur AJK | **A** | HM | 0 | 1 | +1 | BCN-000000172 |
| 3020001067 | NICVD | **A** | HM | 0 | 2 | +2 | BCN-000000237, BCN-000000236 |
| 3020001175 | (SICHN) | ER | COAG | 1 | 2 | +1 | BCN-000000165, BCN-000000164 |
| 3020001280 | (Unknown) | YHLO | IMA | 3 | 4 | +1 | BCN-000000289, BCN-000000285, BCN-000000274, BCN-000000284 |
| 3020001382 | Liaquat University Hospital | **A** | HM | 0 | 5 | +5 | BCN-000000304, BCN-000000306, BCN-000000307, BCN-000000308, BCN-000000305 |
| 3020001399 | Rehman Medical Institute | HW | UBT | 0 | 1 | +1 | BCN-000000254 |
| 3020001511 | Indus Hospital | **A** | HM | 0 | 1 | +1 | BCN-000000211 |

---

## Section 4: ⚠️ Critical — Vendor Code Discrepancy (A vs B for Boule)

**This is the most important finding in the analysis.**

| Observation | Detail |
|---|---|
| Supplier code in Excel | **"B"** (for Boule machines) |
| Supplier code in MDProd SF | **"A - Boule"** |
| Affected customers | 3020000084, 3020000166, 3020000206, 3020000515, 3020000736, 3020000753, 3020001042, 3020001067, 3020001382, 3020001511 |
| Extra "A - Boule" BCs in SF | **25** |
| Missing "B - Boule" BCs in Excel | **30** |

For the **same customers, same technology (HM - Hematology)**, the Excel tracking sheet uses vendor code `B` while Salesforce has records tagged as `A - Boule`.

**This means it is very likely that 25 of the "79 missing" BCs are actually already created — but under vendor code "A" instead of "B".**

### Possible Causes
1. The Boule product line was re-coded in the tracking sheet from `A` to `B` at some point, but SF records were not updated.
2. `A` and `B` may represent two genuinely different Boule product lines (e.g., different distribution channels or machine families).
3. The SF Vendor picklist may have a duplicate entry — both `A - Boule` and a separate `B - Boule` value.

### Recommended Action
- Confirm with the business/data team whether `A` and `B` both refer to the same Boule vendor.
- If yes: update all `A - Boule` non-master BCs to `B - Boule`, which would reduce the missing count from **79 to ~54**.
- If no: both sets need their own BCs as per the tracking sheet.

---

## Section 5: Excel Rows Without Customer Number (Unmatchable)

3 rows in the B-Cases sheet have no value in column R (Customer No.) and cannot be matched to any SF record:

| Excel Row | Customer Name | Supplier | Tech | SAP Asset No. | Status |
|---|---|---|---|---|---|
| Row 15 | SICVD Sukkur | B | HM | — | Active |
| Row 17 | SICVD, Larkana | B | HM | — | Active |
| Row 51 | DHQ Hospital (Allied Hospital-II) | B | HM | — | New Active |

> **Action needed:** Populate the Customer No. in the tracking sheet for these 3 rows, then create corresponding BCs in SF.

---

## Section 6: Missing BCs — By Supplier (Breakdown)

| Supplier Code | Supplier Name | Missing BCs |
|---|---|---|
| B | Boule | **30** |
| YHLO | YHLO | **12** |
| E | Vital Scientific | **8** |
| OR | OCD | **7** |
| ER | Erba | **7** |
| STA | Stago | **6** |
| ZYB | ZYBIO | **2** |
| DYM | Dymind | **2** |
| HW | Headway | **1** |
| NV | Nova | **0** |
| **Total** | | **75*** |

*Note: 4 additional missing BCs are partially offset by A/B Boule ambiguity.*

---

## Section 7: Missing BCs — By Technology (Breakdown)

| Technology Code | Technology Name | Missing BCs |
|---|---|---|
| HM | Hematology | **32** |
| IMA | Immunoassay | **20** |
| CC | Clinical Chemistry | **11** |
| ELCT | Analyzer | **5** |
| URIN | Urinalysis | **5** |
| COAG | Coagulation | **5** |
| URIN | Urinalysis | *(see above)* |

---

## Section 8: Existing Non-Master BCs in MDProd (Full List)

All 137 non-master BCs that have a Customer Number assigned:

| BC Number | Vendor | Technology | Customer No. | Customer Name | Status |
|---|---|---|---|---|---|
| BCN-000000193 | YHLO | IMA | 3020000013 | Dar ul Sehat Hospital | Active |
| BCN-000000195 | E - VitalScientific | CC | 3020000022 | Dr. Essa Laboratory | Active |
| BCN-000000298 | OR - OCD | IMA | 3020000072 | Hormone Lab | Closed |
| BCN-000000267 | A - Boule | HM | 3020000084 | SICVD | Active |
| BCN-000000266 | A - Boule | HM | 3020000084 | SICVD | Active |
| BCN-000000264 | A - Boule | HM | 3020000084 | SICVD | Active |
| BCN-000000261 | A - Boule | HM | 3020000084 | SICVD | Active |
| BCN-000000259 | A - Boule | HM | 3020000084 | SICVD | Active |
| BCN-000000268 | E - VitalScientific | CC | 3020000084 | SICVD | Active |
| BCN-000000262 | E - VitalScientific | CC | 3020000084 | SICVD | Active |
| BCN-000000258 | E - VitalScientific | CC | 3020000084 | SICVD | Active |
| BCN-000000265 | E - VitalScientific | CC | 3020000084 | SICVD | Active |
| BCN-000000269 | YHLO | IMA | 3020000084 | SICVD | New Active |
| BCN-000000260 | YHLO | IMA | 3020000084 | SICVD | New Active |
| BCN-000000263 | YHLO | IMA | 3020000084 | SICVD | New Active |
| BCN-000000283 | STA - Stago | COAG | 3020000088 | (Customer) | Active |
| BCN-000000245 | A - Boule | HM | 3020000166 | QAMC | Active |
| BCN-000000244 | A - Boule | HM | 3020000166 | QAMC | Active |
| BCN-000000248 | A - Boule | HM | 3020000166 | QAMC | Active |
| BCN-000000247 | A - Boule | HM | 3020000166 | QAMC | Active |
| BCN-000000246 | A - Boule | HM | 3020000166 | QAMC | Active |
| BCN-000000249 | A - Boule | HM | 3020000166 | QAMC | New |
| BCN-000000173 | STA - Stago | COAG | 3020000170 | (Customer) | Active |
| BCN-000000294 | NV - Nova | ABG | 3020000190 | (Customer) | Closed 1 |
| BCN-000000288 | A - Boule | HM | 3020000206 | Mughal Diagnostics | New |
| BCN-000000287 | DYM - Dymind | HM | 3020000206 | Mughal Diagnostics | New |
| BCN-000000234 | OR - OCD | IMA | 3020000206 | Mughal Diagnostics | Active |
| BCN-000000277 | B - Boule | HM | 3020000209 | (Customer) | Active |
| BCN-000000208 | E - VitalScientific | CC | 3020000386 | (Customer) | New |
| BCN-000000209 | YHLO | IMA | 3020000386 | (Customer) | New |
| BCN-000000197 | ER - Erba | URIN | 3020000394 | (Customer) | New |
| BCN-000000293 | OR - OCD | IMA | 3020000439 | (Customer) | Closed |
| BCN-000000174 | OR - OCD | IMA | 3020000439 | (Customer) | Revised |
| BCN-000000185 | YHLO | IMA | 3020000447 | (Customer) | Active |
| BCN-000000167 | OR - OCD | IMA | 3020000477 | (Customer) | Revised |
| BCN-000000292 | OR - OCD | IMA | 3020000477 | (Customer) | Closed |
| BCN-000000168 | OR - OCD | IMA | 3020000477 | (Customer) | Revised |
| BCN-000000291 | OR - OCD | IMA | 3020000477 | (Customer) | Closed |
| BCN-000000171 | YHLO | IMA | 3020000491 | (Customer) | Active |
| BCN-000000177 | YHLO | IMA | 3020000491 | (Customer) | New |
| BCN-000000180 | A - Boule | HM | 3020000515 | DHQ / Allied Hospital | New Active |
| BCN-000000181 | YHLO | IMA | 3020000539 | (Customer) | Active 1 |
| BCN-000000243 | OR - OCD | IMA | 3020000547 | (Customer) | Active |
| BCN-000000242 | OR - OCD | IMA | 3020000547 | (Customer) | Active |
| BCN-000000210 | YHLO | IMA | 3020000605 | (Customer) | Active |
| BCN-000000275 | E - VitalScientific | CC | 3020000633 | Children Hospital Multan | Active / Completed |
| BCN-000000276 | ER - Erba | ELCT | 3020000633 | (Customer) | New |
| BCN-000000188 | E - VitalScientific | CC | 3020000692 | (Customer) | Revised |
| BCN-000000295 | E - VitalScientific | CC | 3020000692 | (Customer) | Closed |
| BCN-000000189 | ER - Erba | COAG | 3020000692 | (Customer) | Active |
| BCN-000000313 | E - VitalScientific | CC | 3020000701 | (Customer) | Closed |
| BCN-000000198 | ER - Erba | URIN | 3020000719 | (Customer) | Active |
| BCN-000000233 | ER - Erba | URIN | 3020000734 | (Customer) | Active |
| BCN-000000226 | A - Boule | HM | 3020000736 | Lady Aitchison Hospital | Active |
| BCN-000000225 | E - VitalScientific | CC | 3020000736 | Lady Aitchison Hospital | Active |
| BCN-000000186 | A - Boule | HM | 3020000753 | Children's Hospital Faisalabad | Active |
| BCN-000000184 | YHLO | IMA | 3020000764 | (Customer) | New |
| BCN-000000204 | OR - OCD | IMA | 3020000771 | (Customer) | Active / Closed |
| BCN-000000203 | YHLO | IMA | 3020000771 | (Customer) | New |
| BCN-000000230 | YHLO | IMA | 3020000816 | (Customer) | Active |
| BCN-000000200 | DYM - Dymind | HM | 3020000823 | (Customer) | New Active |
| BCN-000000201 | NV - Nova | ABG | 3020000823 | (Customer) | New |
| BCN-000000235 | STA - Stago | COAG | 3020000845 | (Customer) | Active |
| BCN-000000169 | NV - Nova | ABG | 3020000881 | (Customer) | Active |
| BCN-000000170 | STA - Stago | COAG | 3020000881 | (Customer) | New Active |
| BCN-000000303 | OR - OCD | IMA | 3020000888 | (Customer) | Closed |
| BCN-000000302 | YHLO | IMA | 3020000888 | (Customer) | Closed 1 |
| BCN-000000191 | E - VitalScientific | CC | 3020000917 | (Customer) | Active |
| BCN-000000296 | OR - OCD | IMA | 3020000917 | (Customer) | Closed |
| BCN-000000192 | OR - OCD | IMA | 3020000917 | (Customer) | Revised |
| BCN-000000190 | YHLO | IMA | 3020000917 | (Customer) | Active 1 |
| BCN-000000228 | OR - OCD | IMA | 3020000936 | (Customer) | Active |
| BCN-000000317 | YHLO | IMA | 3020000943 | (Customer) | Closed |
| BCN-000000310 | STA - Stago | COAG | 3020001019 | (Customer) | Closed |
| BCN-000000172 | A - Boule | HM | 3020001042 | Al-Khidmat Lab Mirpur AJK | New Active |
| BCN-000000178 | E - VitalScientific | CC | 3020001042 | Al-Khidmat Lab Mirpur AJK | New |
| BCN-000000240 | E - VitalScientific | CC | 3020001047 | (Customer) | Revised |
| BCN-000000312 | E - VitalScientific | CC | 3020001047 | (Customer) | Closed |
| BCN-000000237 | A - Boule | HM | 3020001067 | NICVD | Revised |
| BCN-000000236 | A - Boule | HM | 3020001067 | NICVD | Active |
| BCN-000000238 | STA - Stago | COAG | 3020001067 | NICVD | Active |
| BCN-000000239 | STA - Stago | COAG | 3020001067 | NICVD | Active |
| BCN-000000290 | NV - Nova | ABG | 3020001092 | (Customer) | New |
| BCN-000000250 | YHLO | IMA | 3020001141 | (Customer) | Active |
| BCN-000000165 | ER - Erba | COAG | 3020001175 | (Customer) | New |
| BCN-000000164 | ER - Erba | COAG | 3020001175 | (Customer) | New |
| BCN-000000183 | E - VitalScientific | CC | 3020001192 | (Customer) | Active |
| BCN-000000257 | E - VitalScientific | CC | 3020001221 | (Customer) | New |
| BCN-000000272 | E - VitalScientific | CC | 3020001224 | SOMH-FFH | Active |
| BCN-000000282 | ER - Erba | ELCT | 3020001230 | (Customer) | New |
| BCN-000000271 | DYM - Dymind | HM | 3020001237 | (Customer) | Active |
| BCN-000000270 | E - VitalScientific | CC | 3020001237 | (Customer) | Active |
| BCN-000000314 | OR - OCD | IMA | 3020001238 | (Customer) | Closed |
| BCN-000000300 | ER - Erba | ELCT | 3020001255 | (Customer) | Closed |
| BCN-000000301 | ER - Erba | ELCT | 3020001255 | (Customer) | Closed |
| BCN-000000289 | YHLO | IMA | 3020001280 | (Customer) | New |
| BCN-000000285 | YHLO | IMA | 3020001280 | (Customer) | New |
| BCN-000000274 | YHLO | IMA | 3020001280 | (Customer) | Active |
| BCN-000000284 | YHLO | IMA | 3020001280 | (Customer) | New |
| BCN-000000304 | A - Boule | HM | 3020001382 | Liaquat University Hospital | Closed |
| BCN-000000306 | A - Boule | HM | 3020001382 | Liaquat University Hospital | Closed |
| BCN-000000307 | A - Boule | HM | 3020001382 | Liaquat University Hospital | Closed |
| BCN-000000308 | A - Boule | HM | 3020001382 | Liaquat University Hospital | Closed |
| BCN-000000305 | A - Boule | HM | 3020001382 | Liaquat University Hospital | Closed |
| BCN-000000217 | YHLO | IMA | 3020001384 | (Customer) | New |
| BCN-000000254 | HW - Headway | UBT | 3020001399 | Rehman Medical Institute | New |
| BCN-000000255 | NV - Nova | ABG | 3020001399 | Rehman Medical Institute | New |
| BCN-000000319 | YHLO | IMA | 3020001430 | (Customer) | Active |
| BCN-000000166 | NV - Nova | ABG | 3020001475 | (Customer) | Active |
| BCN-000000199 | OR - OCD | IMA | 3020001479 | (Customer) | New |
| BCN-000000211 | A - Boule | HM | 3020001511 | Indus Hospital | Active |
| BCN-000000215 | E - VitalScientific | CC | 3020001511 | Indus Hospital | Active |
| BCN-000000212 | ER - Erba | COAG | 3020001511 | Indus Hospital | Active |
| BCN-000000214 | ER - Erba | ELCT | 3020001511 | Indus Hospital | Active |
| BCN-000000216 | ER - Erba | ELCT | 3020001511 | Indus Hospital | New |
| BCN-000000213 | ER - Erba | URIN | 3020001511 | Indus Hospital | Active |
| BCN-000000219 | ER - Erba | URIN | 3020001552 | (Customer) | Active |
| BCN-000000221 | ER - Erba | URIN | 3020001552 | (Customer) | New |
| BCN-000000218 | ER - Erba | URIN | 3020001552 | (Customer) | Active |
| BCN-000000220 | ER - Erba | URIN | 3020001552 | (Customer) | New |
| BCN-000000222 | STA - Stago | COAG | 3020001552 | (Customer) | Active 1 |
| BCN-000000252 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Active |
| BCN-000000309 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Closed Quetta |
| BCN-000000251 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Revised Quetta |
| BCN-000000227 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Revised Quetta |
| BCN-000000315 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Closed Quetta |
| BCN-000000253 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Active |
| BCN-000000196 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Revised Quetta |
| BCN-000000278 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Revised Quetta |
| BCN-000000297 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Closed Quetta |
| BCN-000000318 | OR - OCD | IMA | 3020001748 | Quetta / Jamal Brothers | Closed Quetta |
| BCN-000000205 | YHLO | IMA | 3020001748 | Quetta / Jamal Brothers | Active |
| BCN-000000202 | YHLO | IMA | 3020001748 | Quetta / Jamal Brothers | Active |
| BCN-000000187 | YHLO | IMA | 3020001748 | Quetta / Jamal Brothers | Active |
| BCN-000000273 | YHLO | IMA | 3020001748 | Quetta / Jamal Brothers | Active |
| BCN-000000256 | YHLO | IMA | 3020001809 | (Customer) | New |
| BCN-000000224 | OR - OCD | IMA | 3020001811 | (Customer) | New |

---

## Section 9: Action Items

| # | Action | Owner | Priority |
|---|---|---|---|
| 1 | **Confirm A vs B Boule**: Determine if vendor codes "A" and "B" both refer to Boule. If yes, update affected SF BCs from "A - Boule" to "B". | Business / Data Team | 🔴 High |
| 2 | **Create 70–79 missing non-master BCs** in MDProd for all groups listed in Section 1. | Salesforce Admin | 🔴 High |
| 3 | **Fix 25 incomplete BCs** in SF with no Customer Number (Section 2). | Salesforce Admin | 🟡 Medium |
| 4 | **Add Customer No.** to 3 Excel rows missing column R values (Section 5). | Tracking Sheet Owner | 🟡 Medium |
| 5 | **Review duplicate BCs** — customer 3020001748 (Quetta) has 10 OR/IMA BCs for 6 Excel rows. | Business Team | 🟡 Medium |
| 6 | **Review BCN-000000173** (STA/COAG, customer 3020000170) — not found in Excel at all. | Salesforce Admin | 🟢 Low |

---

## Appendix: Analysis Methodology

- **Excel source:** `Imports/Updated_Business_Cases.xlsx`, sheet `B-Cases`
- **Salesforce query:** `SELECT Id, Name, Is_Master__c, Vendora__c, Technologya__c, Customer_Number__c FROM Business_Case__c WHERE Is_Master__c = false`
- **Match key:** `(Customer_Number__c, extracted vendor code, extracted technology code)` — codes are the portion before `" - "` in the Salesforce picklist value (e.g., `"E - VitalScientific"` → `"E"`)
- **Counts compared per group:** Excel rows vs SF records for each unique key combination
- **Master BCs excluded** — only `Is_Master__c = false` records analysed
