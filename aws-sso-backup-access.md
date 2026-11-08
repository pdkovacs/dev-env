# AWS SSO access limited to the backup buckets

Step-by-step setup of an IAM Identity Center (AWS SSO) login that can do **only** what
[obsidian-backup.sh](bin-dir/obsidian-backup.sh) and [claude-backup.sh](bin-dir/claude-backup.sh) need, and nothing else.

## What the scripts need

| Script | Bucket | Key |
|---|---|---|
| obsidian-backup.sh | `obsidian-pdkovacs-github-io` | `uploads/Obsidian Vault.tar.xz` |
| claude-backup.sh | `claude-pdkovacs-github-io` | `uploads/claude-backup.tar.xz` |

S3 API calls used (`aws s3api ...`):

| CLI call | IAM action |
|---|---|
| `put-object` (backup) | `s3:PutObject` |
| `head-object` (verify checksum, restore timestamp) | `s3:GetObject` |
| `get-object` (restore) | `s3:GetObject` |

`s3:ListBucket` is not strictly required, but without it a missing object gives `403` instead of `404`,
which makes errors confusing. It is included below, restricted to the `uploads/` prefix.

The scripts do not create the buckets, so they must already exist.

## Placeholders

Replace these throughout:

- `<REGION>` – region of your Identity Center instance and of the buckets (e.g. `eu-central-1`)
- `<ACCOUNT_ID>` – the 12-digit AWS account that owns the buckets
- `<SSO_START_URL>` – your access portal URL (`https://d-xxxxxxxxxx.awsapps.com/start`)

## 1. Enable IAM Identity Center (one-time)

1. Sign in to the AWS console as an administrator of the management account.
2. Open **IAM Identity Center** and click **Enable** (choose the same `<REGION>` you want to use; it cannot be moved later).
3. Note the **AWS access portal URL** on the Settings page (`<SSO_START_URL>`).

## 2. Create the user

1. IAM Identity Center → **Users** → **Add user**.
2. Fill in username, email, name. Choose to send an email invitation.
3. (Optional) Put the user into a group, e.g. `backup-clients`, and assign permissions to the group instead of the user.
4. Open the invitation email, accept it, set a password, and register an MFA device
   (Settings → Authentication → configure MFA to be required).

## 3. Create the permission set

1. IAM Identity Center → **Permission sets** → **Create permission set**.
2. Choose **Custom permission set**.
3. Do **not** attach any AWS managed policies.
4. Under **Inline policy**, paste:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "ReadWriteBackupObjects",
         "Effect": "Allow",
         "Action": [
           "s3:PutObject",
           "s3:GetObject"
         ],
         "Resource": [
           "arn:aws:s3:::obsidian-pdkovacs-github-io/uploads/*",
           "arn:aws:s3:::claude-pdkovacs-github-io/uploads/*"
         ]
       },
       {
         "Sid": "ListBackupPrefixOnly",
         "Effect": "Allow",
         "Action": "s3:ListBucket",
         "Resource": [
           "arn:aws:s3:::obsidian-pdkovacs-github-io",
           "arn:aws:s3:::claude-pdkovacs-github-io"
         ],
         "Condition": {
           "StringLike": { "s3:prefix": ["uploads/*"] }
         }
       }
     ]
   }
   ```

5. Name it `S3BackupOnly`, set the session duration (e.g. 8 hours), and create it.

Notes:

- No `s3:DeleteObject`: a compromised session cannot delete backups. If the buckets have versioning enabled,
  an overwrite is also recoverable.
- If the buckets use **SSE-KMS** with a customer-managed key, add `kms:GenerateDataKey` (upload) and `kms:Decrypt`
  (download/head) on that key to the policy. Default SSE-S3 needs nothing extra.

## 4. Assign the permission set to the account

1. IAM Identity Center → **AWS accounts** → select `<ACCOUNT_ID>` → **Assign users or groups**.
2. Select the user (or group) from step 2 → **Next**.
3. Select the `S3BackupOnly` permission set → **Next** → **Submit**.

## 5. Configure the AWS CLI on the machine

```bash
aws configure sso
```

Answer the prompts:

| Prompt | Value |
|---|---|
| SSO session name | `backup` |
| SSO start URL | `<SSO_START_URL>` |
| SSO region | `<REGION>` |
| SSO registration scopes | `sso:account:access` (default) |

A browser opens; sign in as the new user and approve. Then pick the account and the `S3BackupOnly` role, and set:

- default client region: `<REGION>`
- output format: `json`
- profile name: `backup`

This writes to `~/.aws/config`:

```ini
[profile backup]
sso_session = backup
sso_account_id = <ACCOUNT_ID>
sso_role_name = S3BackupOnly
region = <REGION>

[sso-session backup]
sso_start_url = <SSO_START_URL>
sso_region = <REGION>
sso_registration_scopes = sso:account:access
```

## 6. Point the shell at the profile

[.bashrc](dotfiles/.bashrc) warns when `AWS_PROFILE` is empty and expects it in `~/.bashrc.local` (not in the repo):

```bash
echo 'export AWS_PROFILE=backup' >> ~/.bashrc.local
source ~/.bashrc
```

## 7. Log in and verify

```bash
aws sso login                      # repeat whenever the session expires
aws sts get-caller-identity        # should show the S3BackupOnly assumed role
```

Positive checks (should succeed):

```bash
obsidian-backup.sh
claude-backup.sh
obsidian-backup.sh restore --force   # optional full round trip
```

Negative checks (should fail with `AccessDenied`):

```bash
aws s3api list-buckets
aws s3api delete-object --bucket obsidian-pdkovacs-github-io --key "uploads/Obsidian Vault.tar.xz"
aws s3api put-object --bucket obsidian-pdkovacs-github-io --key other/test.txt --body /etc/hostname
aws ec2 describe-instances
```

## Troubleshooting

- `The SSO session associated with this profile has expired` → run `aws sso login`.
- `403` / `AccessDenied` on `head-object` during backup → check the bucket/key prefix matches `uploads/*` and, with SSE-KMS, the KMS permissions.
- `Could not reach s3://...` on restore with a 404 → the backup has never been uploaded; run a backup first.
- `Unable to locate credentials` → `AWS_PROFILE` is not exported in the current shell.
