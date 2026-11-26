-- Back up first. Run ALTER only once; if already applied, skip ALTER.
-- Do not rename categories.name or questions.category. Preserve IDs, slugs and links.
SET NAMES utf8mb4;
ALTER TABLE categories
  ADD COLUMN name_bn VARCHAR(120) NULL,
  ADD COLUMN name_en VARCHAR(120) NULL;

DROP TEMPORARY TABLE IF EXISTS category_label_seed;
CREATE TEMPORARY TABLE category_label_seed (
  canonical_name VARCHAR(120) NOT NULL PRIMARY KEY,
  name_bn VARCHAR(120) NOT NULL,
  name_en VARCHAR(120) NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO category_label_seed VALUES
('ফায়ার সেইফটি','ফায়ার সেইফটি','Fire Safety'),
('BNBC','BNBC','BNBC'),
('NFPA','NFPA','NFPA'),
('ফায়ার ডিটেকশন ও অ্যালার্ম','ফায়ার ডিটেকশন ও অ্যালার্ম','Fire Detection & Alarm'),
('ফায়ার প্রোটেকশন সিস্টেম','ফায়ার প্রোটেকশন সিস্টেম','Fire Protection Systems'),
('ইলেকট্রিক্যাল সেফটি','ইলেকট্রিক্যাল সেফটি','Electrical Safety'),
('ইন্ডাস্ট্রিয়াল সেফটি','ইন্ডাস্ট্রিয়াল সেফটি','Industrial Safety'),
('ফার্স্ট এইড','ফার্স্ট এইড','First Aid'),
('সাধারণ জ্ঞান','সাধারণ জ্ঞান','General Knowledge'),
('বাংলা','বাংলা','Bangla'),
('ইংরেজি','ইংরেজি','English'),
('গণিত','গণিত','Mathematics'),
('RSC Technical Guideline & Standard','RSC টেকনিক্যাল গাইডলাইন ও স্ট্যান্ডার্ড','RSC Technical Guideline & Standard'),
('Nirapon','Nirapon','Nirapon'),
('Bangladesh Labour Law','বাংলাদেশ শ্রম আইন','Bangladesh Labour Law'),
('Fire Safety Fundamentals','ফায়ার সেইফটির মৌলিক বিষয়','Fire Safety Fundamentals'),
('Fire Extinguishers','অগ্নিনির্বাপক যন্ত্র','Fire Extinguishers'),
('Fire Fighting Systems','অগ্নিনির্বাপণ ব্যবস্থা','Fire Fighting Systems'),
('Fire Pumps','ফায়ার পাম্প','Fire Pumps'),
('Fire Pumps & Hydraulics','ফায়ার পাম্প ও হাইড্রলিক্স','Fire Pumps & Hydraulics'),
('Automatic Sprinkler Systems','স্বয়ংক্রিয় স্প্রিংকলার সিস্টেম','Automatic Sprinkler Systems'),
('Occupational Health & Safety','পেশাগত স্বাস্থ্য ও নিরাপত্তা','Occupational Health & Safety'),
('Means of Egress','নিরাপদ বহির্গমন পথ','Means of Egress'),
('BNBC & Building Codes','BNBC ও বিল্ডিং কোড','BNBC & Building Codes'),
('Electrical & Mechanical Safety','ইলেকট্রিক্যাল ও মেকানিক্যাল সেফটি','Electrical & Mechanical Safety'),
('Emergency & Evacuation','জরুরি পরিস্থিতি ও নিরাপদ স্থানান্তর','Emergency & Evacuation'),
('Emergency & Evacuation Planning','জরুরি পরিস্থিতি ও স্থানান্তর পরিকল্পনা','Emergency & Evacuation Planning'),
('Fire Safety Forms & Checklists','ফায়ার সেইফটি ফরম ও চেকলিস্ট','Fire Safety Forms & Checklists'),
('Fire Safety Inspection & Maintenance','ফায়ার সেইফটি পরিদর্শন ও রক্ষণাবেক্ষণ','Fire Safety Inspection & Maintenance'),
('Fire Safety Interview Preparation','ফায়ার সেইফটি ইন্টারভিউ প্রস্তুতি','Fire Safety Interview Preparation'),
('Industrial & Factory Safety','শিল্প ও কারখানার নিরাপত্তা','Industrial & Factory Safety'),
('Inspection, Testing & Maintenance','পরিদর্শন, পরীক্ষা ও রক্ষণাবেক্ষণ','Inspection, Testing & Maintenance'),
('Interview & Job Preparation','ইন্টারভিউ ও চাকরির প্রস্তুতি','Interview & Job Preparation'),
('Sprinkler & Standpipe Systems','স্প্রিংকলার ও স্ট্যান্ডপাইপ সিস্টেম','Sprinkler & Standpipe Systems'),
('Standpipe & Hose Systems','স্ট্যান্ডপাইপ ও হোস সিস্টেম','Standpipe & Hose Systems'),
('কমপ্লায়েন্স','কমপ্লায়েন্স','Compliance'),
('টেকনিক্যাল','টেকনিক্যাল','Technical'),
('মডেল টেস্ট','মডেল টেস্ট','Model Test'),
('General','সাধারণ','General'),
('Electrical Safety','ইলেকট্রিক্যাল সেফটি','Electrical Safety'),
('Industrial Safety','ইন্ডাস্ট্রিয়াল সেফটি','Industrial Safety'),
('Fire Detection & Alarm','ফায়ার ডিটেকশন ও অ্যালার্ম','Fire Detection & Alarm'),
('Fire Detection & Alarm Systems','ফায়ার ডিটেকশন ও অ্যালার্ম সিস্টেম','Fire Detection & Alarm Systems'),
('NFPA Standards','NFPA স্ট্যান্ডার্ড','NFPA Standards'),
('RSC Requirements','RSC-এর প্রয়োজনীয়তা','RSC Requirements'),
('RSC Technical Guidelines','RSC টেকনিক্যাল গাইডলাইন','RSC Technical Guidelines'),
('Nirapon Requirements','Nirapon-এর প্রয়োজনীয়তা','Nirapon Requirements'),
('Nirapon Standards','Nirapon স্ট্যান্ডার্ড','Nirapon Standards'),
('Fire Safety','ফায়ার সেইফটি','Fire Safety'),
('ফায়ার সেফটি','ফায়ার সেইফটি','Fire Safety'),
('ফায়ার','ফায়ার','Fire'),
('সেইফটি','সেইফটি','Safety'),
('Fire Protection Systems','ফায়ার প্রোটেকশন সিস্টেম','Fire Protection Systems'),
('First Aid','ফার্স্ট এইড','First Aid'),
('General Knowledge','সাধারণ জ্ঞান','General Knowledge'),
('Bangla','বাংলা','Bangla'),
('English','ইংরেজি','English'),
('Mathematics','গণিত','Mathematics');

START TRANSACTION;
UPDATE categories c JOIN category_label_seed m
  ON CONVERT(c.name USING utf8mb4) COLLATE utf8mb4_unicode_ci=m.canonical_name
SET c.name_bn=COALESCE(NULLIF(TRIM(c.name_bn),''),m.name_bn),
    c.name_en=COALESCE(NULLIF(TRIM(c.name_en),''),m.name_en);
COMMIT;

-- Remaining labels need admin review, not invented translations.
SELECT id,name,category_type,name_bn,name_en FROM categories
WHERE name_bn IS NULL OR TRIM(name_bn)='' OR name_en IS NULL OR TRIM(name_en)=''
ORDER BY category_type,name;
SELECT category_type,COUNT(*) AS total_categories FROM categories GROUP BY category_type;
DROP TEMPORARY TABLE IF EXISTS category_label_seed;
