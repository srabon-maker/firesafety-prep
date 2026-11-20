# Fire Safety BD — নতুন কমিউনিটি ও ছবিসহ পোস্ট

## গুরুত্বপূর্ণ
আগের কমিউনিটি স্ক্রিনে Rafiq/Tania-র পোস্টসহ সব লাইক ও মন্তব্য অ্যাপের লোকাল **ডেমো ডেটা** ছিল। নতুন স্ক্রিনে কেবল সার্ভারের **approved** পোস্ট দেখা যাবে। ডেমো পোস্টগুলো স্বয়ংক্রিয়ভাবে লাইভ সার্ভারে যাবে না।

## cPanel-এ লাইভ করার ধাপ
1. **আগে সম্পূর্ণ MySQL backup নিন।** phpMyAdmin-এ বর্তমান Fire Safety BD ডাটাবেস নির্বাচন করুন।
2. `backend/migrations/20261118_community_photo_posts.sql` একবার Import করুন। এটি বিদ্যমান `community_posts`-এ `image_path` যোগ করে এবং `community_post_likes` তৈরি করে। একই ALTER বারবার চালাবেন না।
3. cPanel File Manager-এ বর্তমান Fire Safety BD সাইটের document root (যেখানে `db.php` এবং `job_submission_review.php` আছে) খুলুন। নিচের mapping অনুসারে আপলোড করুন:
   - `backend/api/community/index.php` → `api/community/index.php`
   - `backend/community_review.php` → `community_review.php`
   - `backend/uploads/community/.htaccess` → `uploads/community/.htaccess`
   - `backend/job_submission_review.php` → `job_submission_review.php` **শুধু যদি বর্তমান লাইভ ফাইলে কোনো custom পরিবর্তন না থাকে**; অন্যথায় বিদ্যমান admin পেজে শুধু `community_review.php` লিংক যোগ করুন।
4. `uploads/community` ফোল্ডার তৈরি করুন; permission সাধারণত 755, uploaded image files 644। ফোল্ডারে PHP/স্ক্রিপ্ট execution নিষিদ্ধ করার `.htaccess` অবশ্যই রাখুন। ডিরেক্টরি লিস্টিং বন্ধ রাখুন।
5. PHP-তে `file_uploads=On`, `upload_max_filesize>=5M`, `post_max_size>=8M`, `fileinfo` extension enabled রাখুন।
6. Admin login করে `https://fire.manobikishwarganj.com/community_review.php` খুলুন। এখান থেকে Pending পোস্ট Approve/Reject এবং প্রকাশিত পোস্ট Hide করা যাবে।
7. **Backend deploy শেষ হওয়ার পর** Codemagic-এর `main` Branch থেকে নতুন APK build করুন।

## পরীক্ষার ক্রম
- লগইন অবস্থায় নতুন পোস্ট লিখে JPG/PNG/WebP ছবি যোগ করুন (সর্বোচ্চ ৫ MB)।
- Submit করলে **Pending** মেসেজ দেখাবে; পাবলিক ফিডে সঙ্গে সঙ্গে দেখা যাবে না।
- Admin approval পেজে নতুন পোস্ট ও ছবি দেখা যাচ্ছে কি না যাচাই করে Approve করুন।
- অ্যাপ refresh করলে পোস্ট ও ছবি দেখাবে। অন্য একটি ফোন/অ্যাকাউন্টেও দেখার কথা।
- Like ও Comment দিয়ে অন্য ফোনে refresh করে দেখুন।
- Reject/Hide করলে ফিড থেকে সরবে।

## নিরাপত্তা ও সীমাবদ্ধতা
- পোস্ট ও ছবি সার্ভারে সংরক্ষিত হয়; আগের মতো লোকাল ডেমো নয়।
- নতুন পোস্টের জন্য লগইন বাধ্যতামূলক; পাবলিক ফিড শুধু approved পোস্ট দেখায়।
- দৈনিক সর্বোচ্চ ৫ পোস্ট/অ্যাকাউন্ট, প্রতি পোস্টে ১ ছবি, সর্বোচ্চ ৫ MB।
- ছবির ধরন ও dimensions সার্ভারে যাচাই হয়। শুধু JPG/PNG/WebP।
- পোস্ট ও ছবি moderation-এর আগে পাবলিক ফিডে প্রকাশিত হয় না। ছবি URL অনুমান করা কঠিন, তবে uploaded file directory-তে URL জানা থাকলে ফাইল দেখা যেতে পারে। সংবেদনশীল ছবি দেবেন না।
- Comments বর্তমানে approved পোস্টে সরাসরি প্রকাশিত হয়। রিপোর্টিং/কমেন্ট moderation, image re-encoding, EXIF metadata removal, paginated infinite scroll ও orphan-image cleanup পরবর্তী কাজ।
- **এই GitHub পরিবর্তন নিজে থেকে cPanel-এ deploy হয় না।** নতুন APK একা ইনস্টল করলে API কাজ করবে না যতক্ষণ না SQL/PHP upload সম্পন্ন হয়।


## Community API deployment diagnostic
নতুন API build-এ নিচের URL খুলে সার্ভার সেটআপ যাচাই করা যাবে:

`https://fire.manobikishwarganj.com/api/community/index.php?action=health`

সফল হলে JSON-এ `ready: true` এবং সব check `true` থাকবে। `posts_table`, `comments_table` বা `likes_table` false হলে সংশ্লিষ্ট database migration/table যাচাই করুন। `upload_directory` বা `upload_writable` false হলে `uploads/community` ফোল্ডার তৈরি করে permission ঠিক করুন। এই endpoint কোনো database credential, path বা SQL error প্রকাশ করে না।
