# My Exam Results — সার্ভার যাচাই

## নিশ্চিত তথ্য
- আগের অ্যাপে API exception একটি সাধারণ বার্তায় লুকানো হতো।
- my_results কেবল নিজের submitted/expired এবং results_released=1 পরীক্ষার ফল ফেরায়।
- বর্তমান .cpanel.yml শুধু Career ফাইল deploy করে; tests.php স্বয়ংক্রিয়ভাবে deploy হয় না।
- লাইভ authenticated API ও database এখানে যাচাই করা হয়নি। তাই কোন production ত্রুটি ঘটছে তা নিশ্চিত নয়।

## প্রথমে read-only database যাচাই
phpMyAdmin-এ অ্যাপের সঠিক database নির্বাচন করে চালান:

```sql
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
AND (
  (TABLE_NAME = 'model_tests' AND COLUMN_NAME IN ('id','title','results_released'))
  OR (TABLE_NAME = 'model_test_attempts' AND COLUMN_NAME IN
    ('id','test_id','user_id','status','started_at','submitted_at','question_count',
     'total_marks','score','correct_count','incorrect_count','unanswered_count','passed'))
)
ORDER BY TABLE_NAME, COLUMN_NAME;
```

প্রত্যাশিত ১৬টি কলাম (model_tests ৩, model_test_attempts ১৩)। কম হলে কোনটি নেই নির্ণয় করুন। বিদ্যমান কলাম পুনরায় ADD করবেন না। DB backup ও অনুমোদনের পরে কেবল অনুপস্থিত migration/column নিয়ে কাজ করুন।

## Deployment
CI সফল ও release অনুমোদনের পরে cPanel-এ বর্তমান api/tests.php ব্যাকআপ নিন; repository backend/api/tests.php-এর যাচাইকৃত সংস্করণ একই live path-এ দিন। PHP syntax পরীক্ষা করুন। Career-only deployment configuration বদলানো হয়নি। অন্য PHP ফাইল বা database অনাবশ্যকভাবে পরিবর্তন করবেন না।

লগইন করা নিজের অ্যাকাউন্ট থেকে নতুন APK-তে ফলাফল খুলে দেখুন। 401 হলে সেশন; 503 + MODEL_TEST_MIGRATION_REQUIRED হলে schema; 404/invalid JSON হলে deployment/API; 500 হলে hosting PHP error log-এ Model test API error খুঁজুন। ব্যক্তিগত session token বা ফলাফল public issue/chat-এ দেবেন না। সফল empty list হলে প্রকাশিত ফলাফল নেই; সেটি error নয়। ফলাফল প্রকাশের নিয়ম শিথিল করবেন না।

Rollback: ব্যাকআপ tests.php ফিরিয়ে দিন। কোনো migration এখানে চালানো হয়নি।
