# 📈 New Analytics Metrics - User Guide

**Quick Reference for Fleet & Claims Analytics**

---

## What's New?

The analytics dashboard and PDF reports now include **4 powerful new metrics**:

### 1️⃣ Deliveries Per Truck
**What it shows:** Number of deliveries completed by each vehicle

**Why it matters:**
- Identify high-performing vehicles
- Spot under-utilized fleet assets
- Plan maintenance schedules
- Optimize vehicle allocation

**Where to find it:**
- PDF Reports: Page 3, "Deliveries Per Truck" table
- Dashboard: Available when exporting to PDF

**Example:**
```
Vehicle A    45 deliveries
Vehicle B    38 deliveries
Vehicle C    32 deliveries
Unassigned   12 deliveries
```

---

### 2️⃣ Total Claims
**What it shows:** Overall number of claims during the selected period

**Why it matters:**
- Track overall claim volume
- Monitor customer satisfaction
- Identify problem periods
- Benchmark against previous periods

**Where to find it:**
- PDF Reports: Page 3, top left box (red highlight)
- Shows in claims summary section

**Metric:** Single number in prominent red box

---

### 3️⃣ Claims Per Customer
**What it shows:** Which customers have filed the most claims

**Why it matters:**
- Identify problematic customer relationships
- Prioritize customer service efforts
- Detect patterns in recurring issues
- Focus retention efforts

**Where to find it:**
- PDF Reports: Page 3, "Top Customers with Claims" table
- Shows top 5 customers by claim volume

**Example:**
```
Customer CUST001    5 claims
Customer CUST002    4 claims
Customer CUST003    3 claims
Customer CUST004    2 claims
Customer CUST005    1 claim
```

---

### 4️⃣ Different Claim Types
**What it shows:** Number of unique claim categories/types

**Why it matters:**
- Understand claim diversity
- Identify specific problem areas
- Plan targeted improvements
- Categorize issues for analysis

**Where to find it:**
- PDF Reports: Page 3, top right box (indigo highlight)
- Shows unique count of claim types

**Metric:** Single number in indigo box

---

## How to Access These Metrics

### Step 1: Navigate to Analytics Dashboard
- Go to Admin Panel
- Select "Analytics & Reports"
- Choose Desktop view (for PDF export)

### Step 2: Select Time Period
- Choose your analysis period:
  - Week (7 days)
  - Month (30 days)
  - Quarter (90 days)
  - Year (365 days)
  - Custom (choose dates)

### Step 3: Generate PDF Report
- Press **Ctrl + E** (keyboard shortcut)
- Or click Export button
- Select **PDF** option
- Click "Generate PDF"

### Step 4: View Page 3
- PDF downloads automatically
- Navigate to **Page 3**
- View Fleet & Claims Analytics

---

## Understanding the Data

### Deliveries Per Truck

**Table Format:**
```
┌──────────────────┬────────────┐
│ Truck/Vehicle    │ Deliveries │
├──────────────────┼────────────┤
│ Vehicle A (ABC1) │     45     │
│ Vehicle B (DEF2) │     38     │
│ Unassigned       │     12     │
└──────────────────┴────────────┘
```

**What to look for:**
- Which vehicle has most deliveries
- Are deliveries evenly distributed?
- Is there high "Unassigned" count? (problem)
- Which vehicles need rest/maintenance?

---

### Claims Summary Section

**Three Key Boxes:**

| Box | Color | Shows | Example |
|-----|-------|-------|---------|
| Total Claims | 🔴 Red | Overall claim count | 25 |
| Unique Customers | 🟣 Purple | Different customers with claims | 8 |
| Claim Types | 🟦 Indigo | Different categories of claims | 3 |

**Interpretation:**
- High total claims + few customer types = widespread issue
- Low total claims + high customer types = diverse issues
- High customers claiming = satisfaction issue to address

---

### Top Customers with Claims

**Table Format:**
```
┌─────────────────────────┬────────┐
│ Customer ID             │ Claims │
├─────────────────────────┼────────┤
│ CUST001                 │   5    │
│ CUST002                 │   4    │
│ CUST003                 │   3    │
└─────────────────────────┴────────┘
```

**What to do:**
1. Contact top claiming customers
2. Understand their issues
3. Implement targeted solutions
4. Track improvement next period

---

## Common Scenarios

### Scenario 1: High Claims from Few Customers
**What it shows:**
```
Total Claims: 20
Unique Customers: 2
Top Customers: CUST001 (12), CUST002 (8)
```

**Action:** 
- Focus on relationship with these 2 customers
- Investigate their specific concerns
- Provide dedicated support
- May indicate service quality issue with specific area

---

### Scenario 2: Many Customers, Few Claims Each
**What it shows:**
```
Total Claims: 25
Unique Customers: 20
Top Customers: All have 1-2 claims
```

**Action:**
- Distribute claims feedback across multiple teams
- Look for systemic issues (training, processes)
- Each team may have different problem areas

---

### Scenario 3: Uneven Truck Utilization
**What it shows:**
```
Vehicle A: 50 deliveries
Vehicle B: 8 deliveries
Vehicle C: 2 deliveries (inactive?)
Unassigned: 30 (problem!)
```

**Action:**
- Rebalance workload across vehicles
- Investigate why Vehicle C is inactive
- Reduce unassigned deliveries
- Improve fleet efficiency

---

## Using the Metrics Together

### Fleet Health Check
1. Review **Deliveries Per Truck** - Are vehicles evenly utilized?
2. Cross-reference with **Claims Per Customer** - Do high-delivery customers also have high claims?
3. Look at **Total Claims** - Is it trending up/down?

### Customer Satisfaction Analysis
1. Check **Claims Per Customer** - Who needs attention?
2. Review **Claim Types** - Are they related to specific vehicles?
3. Filter by delivery vehicles - Do certain trucks cause more claims?

### Performance Trends
1. Compare this period vs previous period
2. Track **Total Claims** - Improving or worsening?
3. Check **Deliveries Per Truck** - Utilization changing?
4. Monitor **Unique Customers** - Growing customer base?

---

## Tips for Better Analysis

### ✅ Do's
- Compare multiple time periods to see trends
- Cross-reference claims with delivery counts
- Use metrics for data-driven decisions
- Share reports with team for insights
- Track improvements over time

### ❌ Don'ts
- Don't make decisions based on single day
- Don't ignore "Unassigned" deliveries
- Don't assume correlation is causation
- Don't ignore patterns in claim types
- Don't forget to follow up on high-claim customers

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Ctrl + E** | Open Export dialog |
| **1** | Switch to Trend chart |
| **2** | Switch to Status chart |
| **3** | Switch to Drivers chart |
| **4** | Switch to Performance chart |
| **Ctrl + F** | Toggle filters panel |
| **F5** | Refresh data |

---

## Integration with Other Reports

### CSV Export
- Export raw data for spreadsheet analysis
- Use for detailed calculations
- Compare trends over time

### Charts & Visualizations
- Visual dashboard for live monitoring
- Real-time metric updates
- Quick status overview

### PDF Reports (3 Pages)
- **Page 1:** Executive Summary & Key Metrics
- **Page 2:** Top Performing Drivers
- **Page 3:** Fleet & Claims Analytics ✨ **NEW**

---

## FAQ

### Q: How often should I review these metrics?
**A:** Weekly for active monitoring, Monthly for trend analysis, Quarterly for strategic planning

### Q: Why is "Unassigned" showing vehicles?
**A:** Deliveries without assigned vehicles - investigate and assign properly for accurate metrics

### Q: Can I compare metrics across different periods?
**A:** Yes! Generate reports for different periods and compare the data manually

### Q: What if a customer shows high claims but low deliveries?
**A:** They may have quality issues - prioritize for customer service follow-up

### Q: How do I improve "Deliveries Per Truck"?
**A:** Better routing, vehicle maintenance, driver training, and workload balancing

---

## Need More Help?

### For Questions About:
- **PDF Generation:** See PDF_REPORTS_TEST_GUIDE.md
- **Analytics Data:** Check individual dashboard charts
- **Claim Details:** Visit Claims Management section
- **Fleet Management:** Visit Vehicle Management section

---

## Summary

The new Fleet & Claims Analytics section in your PDF reports provides:

✅ Fleet utilization visibility  
✅ Claims tracking by customer  
✅ Issue identification  
✅ Data-driven decisions  
✅ Trend monitoring  

**Use these insights to:**
- Optimize fleet operations
- Improve customer satisfaction
- Identify and solve problems
- Make informed business decisions

---

**Report Generated:** October 21, 2025  
**Feature:** New Analytics Metrics (Deliveries Per Truck, Total Claims, Claims Per Customer, Claim Types)  
**Status:** ✅ Ready for Use

