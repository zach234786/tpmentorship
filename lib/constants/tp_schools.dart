// Temasek Polytechnic's schools and full-time diploma courses, as listed
// on tp.edu.sg (checked 2026-08-10). Update this list if TP adds, renames,
// or retires a course - there is no dynamic source for it in this app.
const Map<String, List<String>> tpSchools = {
  'School of Applied Science': [
    'Common Science Programme',
    'Diploma in Chemical Engineering',
    'Diploma in Food, Nutrition & Culinary Science',
    'Diploma in Medical Biotechnology',
    'Diploma in Pharmaceutical Science',
    'Diploma in Veterinary Technology',
  ],
  'School of Business': [
    'Common Business Programme',
    'Diploma in Accountancy & Finance',
    'Diploma in Business',
    'Diploma in Communications & Media Management',
    'Diploma in Culinary Arts & Management',
    'Diploma in Hospitality & Tourism Management',
    'Diploma in International Trade & Logistics',
    'Diploma in Law & Management',
    'Diploma in Marketing',
  ],
  'School of Design': [
    'Common Design Programme',
    'Diploma in Communication Design',
    'Diploma in Digital Film & Television',
    'Diploma in Fashion Management & Design',
    'Diploma in Interior Architecture & Design',
    'Diploma in Product Experience & Design',
  ],
  'School of Engineering': [
    'Common Engineering Programme',
    'Diploma in Aerospace Electronics',
    'Diploma in Aerospace Engineering',
    'Diploma in Architectural Technology & Building Services',
    'Diploma in Aviation Management',
    'Diploma in Biomedical Engineering',
    'Diploma in Business Process & Systems Engineering',
    'Diploma in Computer Engineering',
    'Diploma in Electrical & Electronic Engineering',
    'Diploma in Integrated Facility Management',
    'Diploma in Mechatronics',
  ],
  'School of Humanities & Social Sciences': [
    // no common programme - students apply directly to one of these three
    'Diploma in Early Childhood Development & Education',
    'Diploma in Psychology Studies',
    'Diploma in Social Sciences in Gerontology',
  ],
  'School of Informatics & IT': [
    'Common ICT Programme',
    'Diploma in Applied Artificial Intelligence',
    'Diploma in Big Data & Analytics',
    'Diploma in Cybersecurity & Digital Forensics',
    'Diploma in Immersive Media & Game Development',
    'Diploma in Information Technology',
  ],
};

// true for the one "explore before you specialise" entry each school
// (other than Humanities & Social Sciences) offers to its Year 1 intake
bool isCommonProgramme(String diploma) => diploma.startsWith('Common ');

// the diplomas selectable for [school] at [academicYear]. Year 1 sees
// everything including the Common Programme; Year 2 and Year 3 have
// already specialised, so the Common Programme is hidden
List<String> diplomasFor(String school, String academicYear) {
  final all = tpSchools[school] ?? const [];
  if (academicYear == 'Year 1') return all;
  return all.where((d) => !isCommonProgramme(d)).toList();
}

// finds which school lists [diploma] (case-insensitive, trimmed), or null.
// used to best-effort-match a profile's existing free-text course value
String? schoolFor(String diploma) {
  final target = diploma.trim().toLowerCase();
  for (final entry in tpSchools.entries) {
    if (entry.value.any((d) => d.toLowerCase() == target)) return entry.key;
  }
  return null;
}
