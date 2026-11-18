# Fire Safety BD — Admin Panel GitHub Version Control

## লক্ষ্য
Flutter অ্যাপ ও PHP Admin Panel একই GitHub রিপোজিটরিতে রক্ষণাবেক্ষণ করা, কিন্তু cPanel-এর লাইভ সার্ভারকে আলাদা deployment target হিসেবে রাখা।

## বর্তমান অবস্থা
- Flutter কোড: `lib/`
- বিদ্যমান PHP API ও কিছু admin page: `backend/`
- cPanel-এর মূল Admin Dashboard (`fire_safety_job_prep_dashboard.php`) এবং অন্যান্য লাইভ PHP ফাইলগুলোর **সম্পূর্ণ, যাচাইকৃত বর্তমান কপি** এখনও রিপোজিটরিতে নেই।
- প্রথমে লাইভ ফাইলগুলোর নিরাপদ ব্যাকআপ/ইনভেন্টরি নিয়ে source control-এ আনতে হবে।
- **GitHub-এ commit বা PR merge করলেই লাইভ cPanel বদলাবে না।**

## প্রস্তাবিত ফাইল ম্যাপিং
| GitHub | cPanel Document Root |
| --- | --- |
| `backend/admin/fire_safety_job_prep_dashboard.php` | `fire_safety_job_prep_dashboard.php` |
| `backend/job_circulars.php` | `job_circulars.php` |
| `backend/job_submission_review.php` | `job_submission_review.php` |
| `backend/community_review.php` | `community_review.php` |
| `backend/api/**` | `api/**` |
| `backend/migrations/**` | **ম্যানুয়াল SQL review/import**, স্বয়ংক্রিয়ভাবে deploy নয় |

এই ম্যাপিং deployment চালুর আগে লাইভ document root অনুযায়ী যাচাই করতে হবে।

## প্রথমবার GitHub-এ আনার নিয়ম
1. cPanel File Manager থেকে **শুধু source code** ZIP করুন (Admin Panel PHP, CSS, JS, প্রয়োজনীয় static assets)।
2. ZIP থেকে নিচের ফাইলগুলো বাদ দিন: `db.php`, `config.php`-এর credentials-সহ সংস্করণ, `.env`, `*.sql` ডাটাবেজ dump, user uploads, cache, logs, backup, `*.jks`, private keys, session files, password/token।
3. `db.php`-এর মতো sensitive config ফাইলের বদলে **dummy example** তৈরি করুন; আসল credentials cPanel-এই থাকবে।
4. প্রতিটি PHP ফাইল পরীক্ষা করে `backend/admin/` বা উপযুক্ত `backend/` পাথে commit করুন।
5. Pull Request → PHP lint → review → merge to `main`।
6. **প্রথম deployment ম্যানুয়াল**: verified files cPanel-এ backup নিয়ে upload করুন; লগইন, Question Bank, Job Circular, Marketplace, Community পরীক্ষা করুন।

## ভবিষ্যতের নিরাপদ Automatic Deployment
- GitHub Actions-এ শুধুমাত্র `backend/`-এর অনুমোদিত ফাইল deploy করা যাবে।
- cPanel SFTP/SSH credential কেবল **GitHub Actions Secrets**-এ থাকবে; কখনো commit বা chat-এ প্রকাশ করবেন না।
- Deployment-এর জন্য manual approval, protected environment, allowlist, dry-run এবং rollback backup রাখুন।
- `db.php`, `.env`, uploads, SQL dump, private keys, `admin_helpers.php`-এর live secrets overwrite করবেন না।
- SQL migration স্বয়ংক্রিয়ভাবে execute করা হবে না; backup ও review-এর পর ম্যানুয়াল।
- CI lint সফল হলেই live deployment অনুমোদন নয়; লাইভ release-এর আগে integration test ও backup দরকার।

## প্রথমবার যাচাই
- Admin Login / Logout
- Dashboard ও Question Bank
- Community list, Pending / Approve / Reject / Hide
- Job Circular list, submission review
- Marketplace add/edit/upload
- Mobile viewport এবং error logs

## গুরুত্বপূর্ণ
এই নথি **প্রক্রিয়ার পরিকল্পনা**। এখনও live cPanel auto-deployment বা credentials সংযোগ করা হয়নি।
