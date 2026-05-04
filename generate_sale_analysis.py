import json

with open('temp_analysis_results.json') as f:
    results = json.load(f)

with open('temp_cust_names.json') as f:
    cust_names = json.load(f)

def cname(cno):
    return cust_names.get(cno, '')

matched = results['matched']
mismatched = results['mismatched']
not_found = results['not_found']

today = '2026-05-04'

def fmt(v):
    return f'{v:,.2f}'

lines = []
lines.append('# Sale Value Analysis Report')
lines.append(f'**Generated:** {today}  ')
lines.append('**Source:** Excel `Imports/Updated_Business_Cases.xlsx` (Sheet: B-Cases, Col BB) vs ZSD Report (SAP ZSD data uploaded to `Invoice_Line_Item__c.Invoice_Value__c`)  ')
lines.append('**Match Criteria:** Customer No. + `DGroup__c = Reagent` + `AG_OG__c LIKE [SupplierCode]-[TechCode]-%`  ')
lines.append('**Tolerance:** ±1')
lines.append('')
lines.append('---')
lines.append('')

# Summary
lines.append('## Summary')
lines.append('')
lines.append('| Category | Count |')
lines.append('|---|---|')
lines.append(f'| Total Business Case Groups (Excel) | {len(matched)+len(mismatched)+len(not_found)} |')
lines.append(f'| Matched (within ±1) | {len(matched)} |')
lines.append(f'| Mismatched | {len(mismatched)} |')
lines.append(f'| Not Found in ZSD Report | {len(not_found)} |')
lines.append('')

total_excel = sum(r['excel_sum'] for r in matched + mismatched + not_found)
total_zsd = sum(r['sf_sum'] for r in matched + mismatched + not_found)
lines.append(f'**Total Excel Sales Value:** PKR {fmt(total_excel)}  ')
lines.append(f'**Total ZSD Sales Value (matched customers):** PKR {fmt(total_zsd)}  ')
lines.append(f'**Total Difference:** PKR {fmt(total_zsd - total_excel)}')
lines.append('')
lines.append('---')
lines.append('')

# Section 1: Matched
lines.append('## 1. Matched Business Cases (Within ±1)')
lines.append('')
lines.append(f'**Count: {len(matched)}**')
lines.append('')
lines.append('| # | Customer No. | Customer Name | Supplier Code | Tech Code | Excel Sum (PKR) | ZSD Sum (PKR) | Diff | ZSD AG_OG(s) |')
lines.append('|---|---|---|---|---|---|---|---|---|')
for i, r in enumerate(sorted(matched, key=lambda x: x['customer_no']), 1):
    ag_ogs = ', '.join(r['sf_ag_ogs']) if r['sf_ag_ogs'] else '-'
    lines.append(f"| {i} | {r['customer_no']} | {cname(r['customer_no'])} | {r['supplier_code']} | {r['tech_code']} | {fmt(r['excel_sum'])} | {fmt(r['sf_sum'])} | {fmt(r['diff'])} | {ag_ogs} |")
lines.append('')
lines.append('---')
lines.append('')

# Section 2: Mismatched
lines.append('## 2. Mismatched Business Cases')
lines.append('')
lines.append(f'**Count: {len(mismatched)}**')
lines.append('')
lines.append('> Sorted by absolute difference (largest gap first).')
lines.append('')
lines.append('| # | Customer No. | Customer Name | Supplier Code | Tech Code | Excel Sum (PKR) | ZSD Sum (PKR) | Diff (ZSD − Excel) | ZSD AG_OG(s) |')
lines.append('|---|---|---|---|---|---|---|---|---|')
for i, r in enumerate(sorted(mismatched, key=lambda x: abs(x['diff']), reverse=True), 1):
    ag_ogs = ', '.join(r['sf_ag_ogs']) if r['sf_ag_ogs'] else '-'
    lines.append(f"| {i} | {r['customer_no']} | {cname(r['customer_no'])} | {r['supplier_code']} | {r['tech_code']} | {fmt(r['excel_sum'])} | {fmt(r['sf_sum'])} | {fmt(r['diff'])} | {ag_ogs} |")
lines.append('')
lines.append('---')
lines.append('')

# Section 3: Not Found
lines.append('## 3. Business Cases Not Found in ZSD Report')
lines.append('')
lines.append(f'**Count: {len(not_found)}**')
lines.append('')
lines.append('These business case triplets (Customer No. + Supplier Code + Tech Code) have no matching records in the ZSD Report where `DGroup__c = Reagent` and `AG_OG__c LIKE [SupplierCode]-[TechCode]-%`.')
lines.append('')
lines.append('| # | Customer No. | Customer Name | Supplier Code | Tech Code | Excel Sum (PKR) | Excel Row(s) |')
lines.append('|---|---|---|---|---|---|---|')
for i, r in enumerate(sorted(not_found, key=lambda x: x['customer_no']), 1):
    rows_str = ', '.join(str(x) for x in r['excel_rows'])
    lines.append(f"| {i} | {r['customer_no']} | {cname(r['customer_no'])} | {r['supplier_code']} | {r['tech_code']} | {fmt(r['excel_sum'])} | {rows_str} |")
lines.append('')
lines.append('---')
lines.append('')
lines.append('*End of Report*')

content = '\n'.join(lines)
with open('Sale_Value_Analysis.md', 'w', encoding='utf-8') as f:
    f.write(content)
print(f'Written Sale_Value_Analysis.md ({len(lines)} lines)')
