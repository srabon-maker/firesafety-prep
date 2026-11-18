# Fire Safety BD — আপলোড করা Admin PHP ফাইলের নাম ও GitHub সমন্বয়

**অবস্থা:** GitHub-এর জন্য প্রস্তুত; এই পরিবর্তনগুলো cPanel-এর লাইভ সার্ভারে স্বয়ংক্রিয়ভাবে আপলোড হয়নি।

## সঠিক ফাইল ম্যাপিং

| ব্যবহারকারীর আপলোড | GitHub-এ রাখা হয়েছে | cPanel-এ লক্ষ্য ফাইল |
| --- | --- | --- |
| `community (1).php` | `backend/admin_helpers.php` | `admin_helpers.php` |
| `marketplace_admin(1).php` | `backend/marketplace_admin.php` | `marketplace_admin.php` |
| `model_tests (1).php` | `backend/model_tests.php` | `model_tests.php` |
| `notes (1).php` | `backend/notes.php` | `notes.php` |
| `questions (2).php` | `backend/questions.php` | `questions.php` |

**বিভ্রান্তিকর নাম:** `community (1).php`-এর ভেতরে community page নয়, বরং `start_secure_session`, `require_admin`, `csrf_token`, `verify_csrf`, এবং `h` helper আছে। তাই `admin_helpers.php` নামে রাখা হয়েছে।

## যেগুলো ইচ্ছাকৃতভাবে Replace করা হয়নি

- `backend/community_review.php` — GitHub-এ ইতিমধ্যে আছে।
- `backend/job_submission_review.php` — GitHub-এ ইতিমধ্যে আছে।
- `backend/admin/fire_safety_job_prep_dashboard.php` — GitHub-এর বর্তমান সংস্করণ অক্ষত রাখা হয়েছে। ব্যবহারকারীর ডাউনলোডের `(2)` সংস্করণ দিয়ে overwrite করা হয়নি।
- `backend/job_circulars.php` — GitHub-এর বর্তমান সংস্করণ অক্ষত রাখা হয়েছে।

## Deploy করার আগে

1. লাইভ cPanel ফাইলগুলোর backup নিন।
2. GitHub `backend/`-এর নতুন পাঁচটি PHP ফাইল একই নামের cPanel document root-এ রাখুন। GitHub-এ dashboard source `backend/admin/`-এ থাকলেও live cPanel-এ এটি document root-এ রাখা হয়।
3. `db.php`-এর লাইভ database credentials সার্ভারেই রাখুন; GitHub-এ commit করবেন না। `admin_helpers.php` এবং `db.php` প্রতিটি admin page-এর পাশে থাকতে হবে।
4. `notes`, `questions`, `model_tests`, `model_test_questions`, `market_*` টেবিল বিদ্যমান আছে কি না যাচাই করুন।
5. PHP `mbstring`, `PDO MySQL`, `ZipArchive`, এবং `DOM` extension পরীক্ষা করুন; প্রশ্নের DOCX import-এর জন্য ZipArchive/DOM প্রয়োজন।
6. Admin login, CSRF-সহ save/delete, DOCX preview/import, model test creation, notes, marketplace—প্রতিটি পেজ staging-এ যাচাই করে তারপর live-এ deploy করুন।

**সতর্কতা:** GitHub PR merge করা মানেই live cPanel update হওয়া নয়। কোনো database dump বা গোপন credential এই পরিবর্তনে যুক্ত করা হয়নি।
