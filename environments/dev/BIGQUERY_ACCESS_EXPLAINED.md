# BigQuery Access Configuration - Simple Guide

## How It Works

We manage BigQuery access using Google Cloud IAM roles and simple lists of email addresses. No complex syntax needed!

## The Three Access Levels

### 1. **Data Owners** (`roles/bigquery.dataOwner` + `roles/bigquery.admin`)
```hcl
dataset_owners = [
  "taki@abc.com",    # Head of AI - Full control
]
```
- Can read data ✓
- Can write/modify data ✓
- Can delete data ✓
- Can manage dataset permissions ✓
- Can delete the dataset ✓
- Can manage BigQuery resources ✓ (admin role)
- Can view and manage all BigQuery jobs ✓ (admin role)
- Can manage BigQuery reservations and capacity ✓ (admin role)

### 2. **Data Editors** (`roles/bigquery.dataEditor`)
```hcl
dataset_writers = [
  "john@abc.com",    # Data Scientist
  "sarah@abc.com",   # ML Engineer
]
```
- Can read data ✓
- Can write/modify data ✓
- Can delete table rows ✓
- Can create/delete tables ✓
- Can manage dataset permissions ✗
- Can delete the dataset ✗

### 3. **Data Viewers** (`roles/bigquery.dataViewer`)
```hcl
dataset_readers = [
  "alice@abc.com",   # Data Analyst
  "bob@abc.com",     # Business Analyst
]
```
- Can read data ✓
- Can export data ✓
- Can write/modify data ✗
- Can delete data ✗
- Can manage permissions ✗

## Adding New Team Members

It's super easy! Just add their email to the right list:

### Example: Adding a New Data Scientist

1. Open `terraform.tfvars`
2. Find the `dataset_writers` list
3. Add the new email:

```hcl
dataset_writers = [
  "john@abc.com",
  "sarah@abc.com",
  "newperson@abc.com",  # ← Just add this line
]
```

4. Save and run: `just apply dev`

That's it! No need to understand complex Terraform syntax.

## Understanding the Code (Optional)

The module now uses proper Google Cloud IAM bindings:

```hcl
# In the BigQuery module
resource "google_bigquery_dataset_iam_binding" "data_editors" {
  dataset_id = google_bigquery_dataset.test_data.dataset_id
  role       = "roles/bigquery.dataEditor"
  
  members = ["user:john@abc.com", "user:sarah@abc.com"]
}
```

This creates IAM bindings that:
1. Grant specific IAM roles to users
2. Are managed separately from the dataset resource
3. Follow Google Cloud best practices

But you don't need to understand this - just update the lists!

## Common Questions

**Q: Can I add comments?**
A: Yes! Use # for comments:
```hcl
dataset_writers = [
  "john@abc.com",     # John - Working on NLP models
  "sarah@abc.com",    # Sarah - Computer vision team
]
```

**Q: What if I need a custom role?**
A: Use the `additional_dataset_access` section (ask DevOps for help)

**Q: How do I remove someone?**
A: Just delete their email from the list and apply

## Testing Your Access

After being added, test your access:

```bash
python scripts/bigquery-tests/04_test_access_summary.py --project-id mycompany-mlops-dev
```

This will show you exactly what you can and cannot do.