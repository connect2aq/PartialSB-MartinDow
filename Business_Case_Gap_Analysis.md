# Business Case Gap Analysis
**Last Updated:** 2026-05-04
**Source:** `Imports/Updated_Business_Cases.xlsx` → Sheet: `B-Cases`
**Target Org:** MDProd (`wajeeh@martindowproject.com.sfdc`) — **READ-ONLY**
**Prepared by:** Claude Code (automated analysis)

---

## Revision History

| Date | Change |
|---|---|
| 2026-05-03 | Initial analysis — 191 Excel rows, 79 missing BCs identified, A vs B Boule discrepancy flagged |
| 2026-05-04 | Re-run after Excel fixes — 200 rows, vendor codes corrected (B→A for Boule), missing count reduced to **64** |

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
| Excel rows in B-Cases sheet | 200 |
| Excel rows with a Customer No. | 197 |
| Excel rows **without** Customer No. (unmatchable) | 3 |
| SF non-master BCs total | 162 |
| SF non-master BCs **with** Customer No. | 137 |
| SF non-master BCs **without** Customer No. (incomplete data) | 25 |
| **Total missing non-master BCs** | **64** |
| Excel rows with zero SF BC match | 49 |

---

## Section 1: Missing Business Cases (Excel > SF)

Groups where the Excel tracking sheet has more records than exist in MDProd.

### 1.1 Groups With Zero BCs in SF (Completely Missing) — 49 records

| # | Customer No. | Customer Name | Supplier | Tech | SAP Asset No. | Status |
|---|---|---|---|---|---|---|
| 1 | 3020000114 | DHO Nawabshah Through HS Medical Nawab Shah | DYM | HM | — | Active |
| 2 | 3020000125 | Minhaj Lab Lahore | E | CC | — | Closed |
| 3 | 3020000135 | Al-Khidmat Welfare Society | ER | URIN | — | New Active |
| 4 | 3020000176 | Attock Hospital (Through Humanity Care Diagnostic) | YHLO | IMA | — | Active |
| 5 | 3020000206 | Mughal Lab Lahore | YHLO | IMA | — | New Active |
| 6 | 3020000314 | Hashmani Hospital | YHLO | IMA | — | Closed |
| 7 | 3020000379 | SASIM Sehwan through Z.A.M Traders & Co. | A | HM | — | Active |
| 8 | 3020000393 | Faisalabad Medical University | A | HM | — | New Active |
| 9 | 3020000393 | Faisalabad Medical University | A | HM | — | New Active |
| 10 | 3020000393 | Faisalabad Medical University | A | HM | — | New Active |
| 11 | 3020000515 | DHQ Hospital (Allied Hospital-II) | E | CC | — | New Active |
| 12 | 3020000580 | Ali Medical Center Islamabad | STA | COAG | 3002000102 | Active |
| 13 | 3020000633 | Children's Hospital Multan | OR | IMA | — | New Active |
| 14 | 3020000633 | Children's Hospital Multan | OR | IMA | — | New Active |
| 15 | 3020000645 | Makhdoom Diagnostic Center MDC | OR | IMA | — | Active |
| 16 | 3020000647 | Alamgir Welfare Trust Int. | ZYB | URIN | — | Active |
| 17 | 3020000664 | NHS | E | CC | — | Active |
| 18 | 3020000664 | NHS | OR | IMA | — | Active |
| 19 | 3020000664 | NHS Sharah-e-Qaideen | YHLO | IMA | — | Active |
| 20 | 3020000678 | Saifee Hospital, Karachi | ZYB | URIN | — | New Active |
| 21 | 3020000685 | Ibn-E-Sina | YHLO | IMA | — | Active |
| 22 | 3020000776 | The Medical Lab Lahore | ER | URIN | 3002000030 | Closed |
| 23 | 3020000811 | Hopes Diagnostics | ER | ELCT | — | Active |
| 24 | 3020000811 | Hopes Diagnostics | ER | URIN | — | Active |
| 25 | 3020000811 | Hopes Diagnostics | STA | COAG | — | Closed |
| 26 | 3020000896 | Sahiwal Teaching Hospital | A | HM | — | New Active |
| 27 | 3020000960 | Arif Memorial Hospital | STA | COAG | 3002000114 | Active |
| 28 | 3020000979 | Medcare International Hospital Gujranwala | E | CC | 3002000115 | Active |
| 29 | 3020000979 | Medcare International Hospital Gujranwala | E | CC | 3002000105 | Active |
| 30 | 3020000979 | Med Care Hospital | OR | IMA | — | Active |
| 31 | 3020000979 | Medcare International Hospital Gujranwala | YHLO | IMA | — | Closed |
| 32 | 3020000987 | Peshawar Fertility & IVF Center | YHLO | IMA | 3002000099 | Active |
| 33 | 3020000998 | Biocare Labs (Private) Limited | YHLO | *(missing)* | 3002000072 | New |
| 34 | 3020001074 | Karachi Institute of Heart Diseases (KIHD) | A | HM | — | Active |
| 35 | 3020001083 | Noor Lab Quetta | YHLO | IMA | 3002000009 | Closed 1 |
| 36 | 3020001086 | GAMCA (Express Medical Center) | OR | IMA | 3002000121 | Active |
| 37 | 3020001102 | GAMCA (Venus Diagnostic Center) | OR | IMA | — | Active |
| 38 | 3020001115 | Al-Khidmat Mashal Medical | DYM | HM | — | New Active |
| 39 | 3020001115 | Al Khidmat Hospital Karachi | STA | URIN | — | New |
| 40 | 3020001124 | Punjab Inst. of Cardiology | OR | IMA | 3002000080 | Active |
| 41 | 3020001124 | Punjab Institute of Cardiology Lahore | STA | COAG | — | New Active |
| 42 | 3020001131 | Metlab-Shahmir Enterprises | YHLO | IMA | — | Active |
| 43 | 3020001174 | Sky Blue Lab Karachi | ER | ELCT | — | Active |
| 44 | 3020001175 | (SICHN) Sindh Inst. of Child Health and Neonatology | YHLO | IMA | — | Closed |
| 45 | 3020001357 | Healthway Laboratories | YHLO | IMA | 3002000100 | Active |
| 46 | 3020001399 | Rehman Medical Institute (Pvt) Ltd | HW | ELCT | — | New |
| 47 | 3020001659 | Imran Idress Hospital / Test Zone | YHLO | IMA | — | Closed |
| 48 | 3020001748 | Fatima Jinnah Inst. of Chest Disease (Jamal Brothers) | ER | ELCT | — | Active |
| 49 | 3020001814 | Al Khidmat Razi Hospital | STA | COAG | 3002000112 | Active |

> **Note row #33:** Customer 3020000998 (Biocare Labs) has no Technology Code in column F — this must be filled in the Excel before a BC can be created.

### 1.2 Groups With Partial BCs in SF (Some Missing) — 15 records

| Customer No. | Customer Name | Supplier | Tech | Excel | SF | Missing | Existing BCs |
|---|---|---|---|---|---|---|---|
| 3020000084 | SICVD | A | HM | 6 | 5 | **1** | BCN-000000267, BCN-000000266, BCN-000000264, BCN-000000261, BCN-000000259 |
| 3020000084 | SICVD | YHLO | IMA | 4 | 3 | **1** | BCN-000000269, BCN-000000260, BCN-000000263 |
| 3020000206 | Mughal Diagnostics | A | HM | 2 | 1 | **1** | BCN-000000288 |
| 3020000206 | Mughal Diagnostics | OR | IMA | 2 | 1 | **1** | BCN-000000234 |
| 3020000515 | DHQ / Faisalabad Medical Univ. (Allied) | A | HM | 3 | 1 | **2** | BCN-000000180 |
| 3020000633 | The Children Hospital / Children's Hospital Multan | E | CC | 2 | 1 | **1** | BCN-000000275 |
| 3020000736 | Lady Aitchison Hospital | A | HM | 2 | 1 | **1** | BCN-000000226 |
| 3020001224 | SOMH-FFH (Shaukat Umar Memorial / Fauji Foundation) | E | CC | 2 | 1 | **1** | BCN-000000272 |
| 3020001511 | Indus Hospital | E | CC | 3 | 1 | **2** | BCN-000000215 |
| 3020001511 | Indus Hospital | ER | ELCT | 3 | 2 | **1** | BCN-000000214, BCN-000000216 |
| 3020001748 | Quetta / Jamal Brothers | YHLO | IMA | 7 | 4 | **3** | BCN-000000205, BCN-000000202, BCN-000000187, BCN-000000273 |

**Subtotal missing from partial groups: 15**

---

## Section 2: SF Non-Master BCs Without Customer Number

25 non-master BCs exist in MDProd but have no `Customer_Number__c` populated — they cannot be matched to any Excel row. These are likely incomplete or pending assignment:

BCN-000000347, BCN-000000343, BCN-000000344, BCN-000000345,
BCN-000000342, BCN-000000341, BCN-000000338, BCN-000000337,
BCN-000000336, BCN-000000335, BCN-000000334, BCN-000000333,
BCN-000000332, BCN-000000331, BCN-000000330, BCN-000000004,
BCN-000000006, BCN-000000179, BCN-000000223, BCN-000000194,
BCN-000000286, BCN-000000176, BCN-000000229, BCN-000000231,
BCN-000000182

> **Action needed:** Review these 25 records — assign a Customer Number so they can be properly matched, or delete if they are test/duplicate records.

---

## Section 3: SF BCs Exceeding Excel Count

The following groups have **more** non-master BCs in SF than rows in Excel.

| Customer No. | Supplier | Tech | Excel | SF | Extra | BC Numbers |
|---|---|---|---|---|---|---|
| 3020000170 | STA | COAG | 0 | 1 | +1 | BCN-000000173 |
| 3020001175 | ER | COAG | 1 | 2 | +1 | BCN-000000165, BCN-000000164 |
| 3020001280 | YHLO | IMA | 3 | 4 | +1 | BCN-000000289, BCN-000000285, BCN-000000274, BCN-000000284 |
| 3020001399 | HW | UBT | 0 | 1 | +1 | BCN-000000254 |

> **Note:** Customer 3020001280 (Test Zone) has 4 BCs in SF but only 3 in Excel — one BC may be a duplicate or relates to a row not yet in the tracking sheet.
> **Note:** BCN-000000173 (STA/COAG, customer 3020000170) and BCN-000000254 (HW/UBT, customer 3020001399) have no corresponding Excel rows at all — verify if these should exist.

---

## Section 4: Excel Rows Without Customer Number (Unmatchable)

3 rows in the B-Cases sheet have no value in column R (Customer No.) and cannot be matched to any SF record:

| Excel Row | Customer Name | Supplier | Tech | SAP Asset No. | Status |
|---|---|---|---|---|---|
| Row 184 | Haemophilia Treatment Center (Molicular Concern) | STA | COAG | — | Closed |
| Row 186 | Tmmergara Clinical Labs – Through JMS | OR | IMA | — | Closed |
| Row 187 | Taj Hematology and Healthcare Center | OR | IMA | — | Closed |

> **Action needed:** Populate the Customer No. in the tracking sheet for these 3 rows, then create corresponding BCs in SF.

---

## Section 5: Missing BCs — By Supplier (Breakdown)

| Supplier Code | Supplier Name | Missing BCs |
|---|---|---|
| YHLO | YHLO | **17** |
| A | Boule | **11** |
| OR | OCD | **9** |
| E | Vital Scientific | **9** |
| ER | Erba | **7** |
| STA | Stago | **6** |
| DYM | Dymind | **2** |
| ZYB | ZYBIO | **2** |
| HW | Headway | **1** |
| **Total** | | **64** |

---

## Section 6: Missing BCs — By Technology (Breakdown)

| Technology Code | Technology Name | Missing BCs |
|---|---|---|
| IMA | Immunoassay | **25** |
| HM | Hematology | **13** |
| CC | Clinical Chemistry | **9** |
| URIN | Urinalysis | **6** |
| COAG | Coagulation | **5** |
| ELCT | Analyzer | **5** |
| *(missing)* | Not set in Excel | **1** |
| **Total** | | **64** |

---

## Section 7: Existing Non-Master BCs in MDProd (Full List)

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

## Section 8: Action Items

| # | Action | Owner | Priority |
|---|---|---|---|
| 1 | **Create 64 missing non-master BCs** in MDProd for all groups in Section 1 | Salesforce Admin | 🔴 High |
| 2 | **Fix Technology Code for Biocare Labs** (row 33, customer 3020000998) — Technology Code is blank in the Excel | Tracking Sheet Owner | 🔴 High |
| 3 | **Add Customer No.** to 3 Excel rows missing column R (rows 184, 186, 187) | Tracking Sheet Owner | 🟡 Medium |
| 4 | **Fix 25 incomplete BCs** in SF with no Customer Number (Section 2) | Salesforce Admin | 🟡 Medium |
| 5 | **Review duplicate BCs** — customer 3020001748 (Quetta/Jamal Brothers) has 10 OR/IMA BCs for 9+ Excel rows | Business Team | 🟡 Medium |
| 6 | **Review SF extra BCs** — BCN-000000173 (STA/COAG, cust 3020000170) and BCN-000000254 (HW/UBT, cust 3020001399) have no corresponding Excel row | Salesforce Admin | 🟢 Low |
| 7 | **Review BCN-000000277** — tagged as `B - Boule` in SF (customer 3020000209); all other Boule BCs use `A - Boule` — confirm if correct | Salesforce Admin | 🟢 Low |

---

## Section 9: Master Business Cases — Full Hierarchy

Master BCs (`Is_Master__c = true`) group individual non-master BCs when the **same customer** has **more than one machine** from the **same supplier** with the **same technology**.

### Counts

| Metric | Count |
|---|---|
| Total Master BCs in MDProd | 22 |
| Total Non-Master BCs | 162 |
| Non-Master BCs linked to a Master | 64 |
| Non-Master BCs with no Master (standalone) | 98 |

### 9.1 All Master BCs and Their Children

| Master BC | Vendor | Tech | Customer No. | Customer Name | Status | Children |
|---|---|---|---|---|---|---|
| BCN-000000320 | OR | IMA | 3020000477 | Aga Khan Hospital & Medical College | Revised | 4 |
| BCN-000000321 | YHLO | IMA | 3020000491 | Al Khidmat Diagnostic Center Faisalabad | New | 2 |
| BCN-000000322 | YHLO | IMA | 3020001748 | Jamal Brothers Enterprises | Active | 4 |
| BCN-000000323 | OR | IMA | 3020001748 | Jamal Brothers Enterprises | Revised Quetta | 9 |
| BCN-000000324 | ER | ELCT | 3020001511 | Indus Hospital & Health Network | New | 2 |
| BCN-000000325 | ER | URIN | 3020001552 | MHK Enterprises | New | 2 |
| BCN-000000326 | ER | URIN | 3020001552 | MHK Enterprises | Active | 2 |
| BCN-000000327 | A | HM | 3020001067 | National Institute of Cardiovascular Diseases (NICVD) | Revised | 2 |
| BCN-000000328 | STA | COAG | 3020001067 | National Institute of Cardiovascular Diseases (NICVD) | Active | 2 |
| BCN-000000329 | OR | IMA | 3020000547 | V-Med Inter Trade | Active | 2 |
| BCN-000000330 | A | HM | 3020000166 | Quaid-e-Azam Medical College (QAMC) | Active | 5 |
| BCN-000000331 | A | HM | 3020000084 | Sindh Institute of Cardiovascular Diseases (SICVD) | Active | 5 |
| BCN-000000332 | E | CC | 3020000084 | Sindh Institute of Cardiovascular Diseases (SICVD) | Active | 4 |
| BCN-000000333 | YHLO | IMA | 3020000084 | Sindh Institute of Cardiovascular Diseases (SICVD) | New Active | 2 |
| BCN-000000334 | YHLO | IMA | 3020001280 | Test Zone | New | 2 |
| BCN-000000335 | OR | IMA | 3020000439 | Al Maisarah Dialysis & Diabetes Trust | Revised | 2 |
| BCN-000000336 | E | CC | 3020000692 | Patients Welfare Foundation | Revised | 2 |
| BCN-000000337 | OR | IMA | 3020000917 | Liaquat University of Medical & Health Sciences | Revised | 2 |
| BCN-000000338 | ER | ELCT | 3020001255 | Jafaria Disaster Cell (JDC) Welfare | Closed | 2 |
| BCN-000000339 | A | HM | 3020001382 | Ojal Enterprises (Liaquat University Hospital) | Closed | 5 |
| BCN-000000340 | E | CC | 3020001047 | North Mehran Diagnostic Centre | Revised | 2 |
| BCN-000000342 | — | — | — | *(no data — empty record)* | Active | 0 |

### 9.2 Detailed Master → Child Mapping

**BCN-000000320** — OR / IMA — Aga Khan Hospital (3020000477) — *Revised*
- BCN-000000167 · OR/IMA · Revised
- BCN-000000168 · OR/IMA · Revised
- BCN-000000291 · OR/IMA · Closed
- BCN-000000292 · OR/IMA · Closed

**BCN-000000321** — YHLO / IMA — Al Khidmat Diagnostic Center Faisalabad (3020000491) — *New*
- BCN-000000171 · YHLO/IMA · Active
- BCN-000000177 · YHLO/IMA · New

**BCN-000000322** — YHLO / IMA — Jamal Brothers Enterprises (3020001748) — *Active*
- BCN-000000187 · YHLO/IMA · Active
- BCN-000000202 · YHLO/IMA · Active
- BCN-000000205 · YHLO/IMA · Active
- BCN-000000273 · YHLO/IMA · Active

**BCN-000000323** — OR / IMA — Jamal Brothers Enterprises (3020001748) — *Revised Quetta*
- BCN-000000196 · OR/IMA · Revised Quetta
- BCN-000000227 · OR/IMA · Revised Quetta
- BCN-000000251 · OR/IMA · Revised Quetta
- BCN-000000252 · OR/IMA · Active
- BCN-000000253 · OR/IMA · Active
- BCN-000000278 · OR/IMA · Revised Quetta
- BCN-000000309 · OR/IMA · Closed Quetta
- BCN-000000315 · OR/IMA · Closed Quetta
- BCN-000000318 · OR/IMA · Closed Quetta

**BCN-000000324** — ER / ELCT — Indus Hospital & Health Network (3020001511) — *New*
- BCN-000000214 · ER/ELCT · Active
- BCN-000000216 · ER/ELCT · New

**BCN-000000325** — ER / URIN — MHK Enterprises (3020001552) — *New*
- BCN-000000220 · ER/URIN · New
- BCN-000000221 · ER/URIN · New

**BCN-000000326** — ER / URIN — MHK Enterprises (3020001552) — *Active*
- BCN-000000218 · ER/URIN · Active
- BCN-000000219 · ER/URIN · Active

**BCN-000000327** — A / HM — NICVD (3020001067) — *Revised*
- BCN-000000236 · A/HM · Active
- BCN-000000237 · A/HM · Revised

**BCN-000000328** — STA / COAG — NICVD (3020001067) — *Active*
- BCN-000000238 · STA/COAG · Active
- BCN-000000239 · STA/COAG · Active

**BCN-000000329** — OR / IMA — V-Med Inter Trade (3020000547) — *Active*
- BCN-000000242 · OR/IMA · Active
- BCN-000000243 · OR/IMA · Active

**BCN-000000330** — A / HM — QAMC (3020000166) — *Active*
- BCN-000000244 · A/HM · Active
- BCN-000000245 · A/HM · Active
- BCN-000000246 · A/HM · Active
- BCN-000000247 · A/HM · Active
- BCN-000000248 · A/HM · Active

**BCN-000000331** — A / HM — SICVD (3020000084) — *Active*
- BCN-000000259 · A/HM · Active
- BCN-000000261 · A/HM · Active
- BCN-000000264 · A/HM · Active
- BCN-000000266 · A/HM · Active
- BCN-000000267 · A/HM · Active

**BCN-000000332** — E / CC — SICVD (3020000084) — *Active*
- BCN-000000258 · E/CC · Active
- BCN-000000262 · E/CC · Active
- BCN-000000265 · E/CC · Active
- BCN-000000268 · E/CC · Active

**BCN-000000333** — YHLO / IMA — SICVD (3020000084) — *New Active*
- BCN-000000263 · YHLO/IMA · New Active
- BCN-000000269 · YHLO/IMA · New Active

**BCN-000000334** — YHLO / IMA — Test Zone (3020001280) — *New*
- BCN-000000284 · YHLO/IMA · New
- BCN-000000289 · YHLO/IMA · New

**BCN-000000335** — OR / IMA — Al Maisarah Dialysis & Diabetes Trust (3020000439) — *Revised*
- BCN-000000174 · OR/IMA · Revised
- BCN-000000293 · OR/IMA · Closed

**BCN-000000336** — E / CC — Patients Welfare Foundation (3020000692) — *Revised*
- BCN-000000188 · E/CC · Revised
- BCN-000000295 · E/CC · Closed

**BCN-000000337** — OR / IMA — Liaquat University of Medical & Health Sciences (3020000917) — *Revised*
- BCN-000000192 · OR/IMA · Revised
- BCN-000000296 · OR/IMA · Closed

**BCN-000000338** — ER / ELCT — Jafaria Disaster Cell (JDC) Welfare (3020001255) — *Closed*
- BCN-000000300 · ER/ELCT · Closed
- BCN-000000301 · ER/ELCT · Closed

**BCN-000000339** — A / HM — Ojal Enterprises / Liaquat University Hospital (3020001382) — *Closed*
- BCN-000000304 · A/HM · Closed
- BCN-000000305 · A/HM · Closed
- BCN-000000306 · A/HM · Closed
- BCN-000000307 · A/HM · Closed
- BCN-000000308 · A/HM · Closed

**BCN-000000340** — E / CC — North Mehran Diagnostic Centre (3020001047) — *Revised*
- BCN-000000240 · E/CC · Revised
- BCN-000000312 · E/CC · Closed

**BCN-000000342** — *(empty master — no vendor, no technology, no customer, no children)* — *Active*
- *(no children linked)*

### 9.3 Master BC Issues

| # | Observation | Detail | Action |
|---|---|---|---|
| 1 | **Duplicate masters for same group** | BCN-000000325 and BCN-000000326 are both `ER / URIN / 3020001552` (MHK Enterprises) — two master BCs for same customer+supplier+tech | Review and merge into one master |
| 2 | **Empty master BC** | BCN-000000342 has no vendor, no technology, no customer, and no children | Delete this record |
| 3 | **98 standalone non-master BCs** | These have no master because each represents a single machine — correct behaviour | No action needed |
| 4 | **New masters needed** | Once the 64 missing non-master BCs are created, master BCs will be needed for any customer+supplier+tech group that will have 2+ machines | Create master BCs when linking multiple children |

---

## Appendix: Analysis Methodology

- **Excel source:** `Imports/Updated_Business_Cases.xlsx`, sheet `B-Cases`
- **SF queries:**
  - Non-master: `SELECT Id, Name, Is_Master__c, Vendora__c, Technologya__c, Customer_Number__c, Customer_Namea__c, Sap_Asset_Number__c, Serial_Numbera__c, Status__c FROM Business_Case__c WHERE Is_Master__c = false`
  - Master: `SELECT Id, Name, Is_Master__c, Vendor__c, Technologyaa__c, Customer_Numbera__c, Customer_Namea__c, Status__c FROM Business_Case__c WHERE Is_Master__c = true`
  - Children linked: `SELECT Id, Name, Master_Business_Case__c, Master_Business_Case__r.Name FROM Business_Case__c WHERE Is_Master__c = false`
- **Match key:** `(Customer_Number__c, extracted vendor code, extracted technology code)` — codes are the portion before `" - "` in the Salesforce picklist value (e.g., `"E - VitalScientific"` → `"E"`)
- **Counts compared per group:** Excel rows vs SF records for each unique key combination
- **Master BCs excluded from gap analysis** — only `Is_Master__c = false` records compared against Excel
