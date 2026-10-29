import 'package:url_launcher/url_launcher.dart';
// opens links, email apps, etc from inside the app
import 'package:tpmentorship/models/mentor.dart';
// the mentor data type

class ShareService {
// additional feature: social sharing and launching weblinks in-app
// uses the url_launcher package - works on both web and mobile

  // opens the user's email app with a ready-made message recommending
  // a mentor to a friend. returns false if no email app could open
  static Future<bool> shareMentorByEmail(Mentor mentor) async {
    // mailto: is a special link type that opens the default email app
    final uri = Uri(
      scheme: 'mailto',
      query: _encodeQuery({
        'subject': 'Check out ${mentor.name} on TP Mentorship!',
        'body': 'Hey!\n\n'
            'I found a great mentor on TP Mentorship:\n\n'
            '${mentor.name} - ${mentor.specialization}\n'
            'Rating: ${mentor.rating}/5 (${mentor.reviewCount} reviews)\n'
            'Subjects: ${mentor.subjects.join(", ")}\n\n'
            'Download TP Mentorship to book a session!',
      }),
    );
    return _tryLaunch(uri);
  }

  // opens the TP website in an in-app browser view
  static Future<bool> openStudyResources() {
    return _tryLaunch(
      Uri.parse('https://www.tp.edu.sg/schools-and-courses.html'),
      inApp: true,
    );
  }

  // actually launches the link, returns false instead of crashing if
  // the device has no app that can handle it
  static Future<bool> _tryLaunch(Uri uri, {bool inApp = false}) async {
    try {
      return await launchUrl(
        uri,
        mode: inApp
            ? LaunchMode.inAppBrowserView
            // opens inside the app so the user doesnt lose their place
            : LaunchMode.externalApplication,
            // email must open the actual email app
      );
    } catch (_) {
      return false;
    }
  }

  // builds the ?subject=...&body=... part of a mailto link
  // with special characters (spaces, newlines) safely encoded
  static String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
