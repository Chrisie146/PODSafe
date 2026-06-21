# Reports Screen - Quick Start Guide

## How to Access Reports

### From Admin Dashboard
1. Log in as an Admin user
2. On the Admin Dashboard, scroll to **Quick Actions**
3. Click the **"Reports"** button (Cyan icon with table chart)
4. Or navigate to `/admin/reports`

### Direct URL
```
http://localhost:5000/#/admin/reports
```

## Report Types Available

### 1. 📦 Deliveries
**Best for**: Tracking delivery performance and volumes
- View all deliveries with status
- See customer and driver assignments
- Track amounts and dates
- Quick view of completion rates

**Use Cases**:
- Daily delivery summary
- Performance by customer
- Revenue tracking
- Route analysis

---

### 2. 👥 Drivers
**Best for**: Managing driver performance and metrics
- See all drivers and their approval status
- Track deliveries completed per driver
- Monitor driver activity
- Identify top performers

**Use Cases**:
- Driver performance reviews
- Identify training needs
- Plan incentives based on delivery counts
- Manage driver approvals

---

### 3. 📋 Claims
**Best for**: Managing claims and disputes
- Track all claims by status
- Monitor claim amounts
- See claim types and reasons
- Calculate approval rates

**Use Cases**:
- Claims management and resolution
- Financial impact analysis
- Dispute tracking
- Budget forecasting

---

### 4. 🏢 Customers
**Best for**: Customer relationship and business analytics
- See all customers and their activity
- Track deliveries per customer
- Monitor customer revenue
- Identify active vs inactive customers

**Use Cases**:
- Customer health assessment
- Revenue concentration analysis
- Customer retention insights
- Growth opportunities

---

### 5. ✅ PODs (Proof of Delivery)
**Best for**: Quality assurance and compliance
- Track signature collection rates
- Monitor photo documentation
- See completion of notes
- Identify gaps in documentation

**Use Cases**:
- Quality assurance checks
- Compliance reporting
- Evidence collection verification
- Training and improvement areas

---

## Using the Reports

### Selecting a Report
**Mobile**: Tap the colored chip buttons at the top
**Desktop**: Click on the report name in the left sidebar

### Changing Date Range
1. Click the **📅 Calendar icon** in the top-right
2. Select start and end dates
3. Click **Apply**
4. Table updates automatically

### Refreshing Data
Click the **🔄 Refresh icon** to reload the latest data

### Understanding Summary Cards

Each report shows key statistics:
- **Cards color-coded by metric type**
- Numbers are large and easy to read
- Percentages show completion/success rates
- Cards update when you change the date range

### Reading the Table

**Column Headers** show what data is displayed
**Color-coded Status**: 
- 🟢 Green = Positive/Completed
- 🟡 Orange = Pending/In Progress
- 🔵 Blue = In Transit/Processing
- 🔴 Red = Rejected/Failed

**Mobile Scrolling**: Swipe left/right to see more columns

---

## Summary Statistics Explained

### Delivery Report
| Metric | Meaning |
|--------|---------|
| **Total** | All deliveries in date range |
| **Completed** | Successfully delivered |
| **Pending** | Not yet assigned/started |
| **In Transit** | Currently being delivered |

### Driver Report
| Metric | Meaning |
|--------|---------|
| **Total Drivers** | All drivers in company |
| **Active** | Currently working drivers |
| **Approved** | Verified and authorized |
| **Pending** | Awaiting approval |

### Claims Report
| Metric | Meaning |
|--------|---------|
| **Total Claims** | All claims filed |
| **Pending** | Awaiting review/decision |
| **Approved** | Accepted and paid |
| **Rejected** | Denied claims |

### Customer Report
| Metric | Meaning |
|--------|---------|
| **Total Customers** | All customers in company |
| **Active Customers** | Customers with recent activity |

### POD Report
| Metric | Meaning |
|--------|---------|
| **Total PODs** | All proofs of delivery |
| **Signed** | With customer signatures |
| **With Photos** | With evidence photos |
| **With Notes** | With driver notes |

---

## Tips & Tricks

### Getting the Most from Reports

**📊 Performance Analysis**
- Use Delivery Report + Driver Report together
- Compare completion rates
- Identify bottlenecks

**💰 Financial Planning**
- Use Claims Report for budget forecasting
- Check Customer Report for revenue concentration
- Monitor trend over time with date ranges

**📈 Growth Opportunities**
- Customer Report shows which accounts are active
- Track new vs returning customers
- Identify customers for expansion

**✅ Quality Assurance**
- POD Report shows documentation compliance
- Use to identify training needs
- Track improvements over time

**👥 Team Management**
- Driver Report shows performance metrics
- Identify top performers for rewards
- Spot issues for coaching

### Best Practices

1. **Check reports regularly** (daily/weekly)
2. **Use date ranges** to spot trends
3. **Combine reports** for deeper insights
4. **Export data** for presentations (future feature)
5. **Set baselines** for comparison

---

## Data Accuracy

### Data Sources
All data comes directly from:
- ✅ Live Firestore database
- ✅ Real-time data (updates within seconds)
- ✅ Company-specific filters (only your company's data)

### Update Frequency
- Reports fetch fresh data each time you:
  - Switch report types
  - Change date range
  - Click refresh button

### What's Included
- All deliveries, claims, drivers, customers, and PODs
- Only data for your company (via companyId)
- All statuses (pending, in progress, completed)

---

## Common Questions

**Q: Why do I not see any data?**
A: 
1. Check your date range - may be too narrow
2. Ensure your user account has admin permissions
3. Verify your company ID is set correctly
4. Click refresh to reload

**Q: Can I export this data?**
A: Export functionality is coming soon. For now:
- Take screenshots of tables
- Export permission exists for future feature

**Q: What time zone is used?**
A: All dates use South African Time (SAST)

**Q: How far back can I go?**
A: You can view data from 2020 onwards

**Q: Is this data real-time?**
A: Yes, data updates within seconds of changes

**Q: Can I customize which columns I see?**
A: Currently columns are fixed. Customization coming in future updates.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No data showing | 1. Check date range is correct<br>2. Verify you have admin access<br>3. Click refresh button |
| Slow loading | 1. Reduce date range<br>2. Check internet connection<br>3. Try again in a moment |
| Wrong company data | 1. Verify you're logged into correct account<br>2. Check company ID in profile |
| Numbers don't match | 1. Compare date ranges<br>2. Check if filters are applied<br>3. Refresh to get latest data |

---

## Report Use Case Examples

### Daily Standup
Use **Delivery Report** to start day with:
- Yesterday's completion rate
- Today's pending deliveries
- Any issues or delays

### Weekly Performance Review
Compare this week vs last week:
1. Pull **Driver Report** for both weeks
2. Note top performers
3. Identify underperformers
4. Plan coaching sessions

### Financial Reconciliation
Use **Claims Report** to:
- Total approved claims
- Compare to budget
- Identify trend in claim types
- Plan provisions

### Customer Success Check-in
Use **Customer Report** to:
- Find inactive customers
- Reach out to top customers
- Spot growth opportunities
- Plan retention activities

### Quality Audit
Use **POD Report** to:
- Check documentation rates
- Identify training gaps
- Set improvement targets
- Track compliance

---

## Future Features Coming

🔄 **Export to PDF/CSV**
📊 **Charts and Graphs**
🔍 **Advanced Filtering**
📧 **Scheduled Email Reports**
⏱️ **Historical Comparisons**
🎯 **Custom Report Builder**

---

**Need Help?**
Contact your system administrator for access or permission issues.

**Report Issues?**
Provide:
1. Report type you were viewing
2. Date range selected
3. Screenshot if possible
4. Expected vs actual data

---

**Last Updated**: October 23, 2025
**Version**: 1.0
