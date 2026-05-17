// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:io';
import 'dart:math';

final rng = Random();

List<String> fill(List<String> templates, Map<String, List<String>> vars, int count) {
  final set = <String>{};
  int attempts = 0;
  while (set.length < count && attempts < count * 50) {
    attempts++;
    String t = templates[rng.nextInt(templates.length)];
    vars.forEach((k, v) {
      while (t.contains('{$k}')) {
        t = t.replaceFirst('{$k}', v[rng.nextInt(v.length)]);
      }
    });
    set.add(t);
  }
  // If we couldn't hit count, pad
  final list = set.toList();
  while (list.length < count) {
    list.add('${list[rng.nextInt(list.length)]} (Tell us more)');
  }
  list.shuffle(rng);
  return list;
}

void main() async {
  final count = 400;
  final outFile = File('lib/games/truth_dare_data.dart');
  final sink = outFile.openWrite();
  sink.writeln('// GENERATED DATA - DO NOT EDIT MANUALLY');
  sink.writeln('class TruthDareData {');
  
  // ── SOCIAL ──
  final socialTruthVars = {
    'person': ['your best friend', 'your crush', 'the host of this room', 'the person who last texted you', 'your mom', 'your ex', 'your teacher', 'your neighbor', 'a stranger'],
    'event': ['a party', 'college', 'school', 'a family gathering', 'a trip', 'a sleepover', 'a wedding', 'a date'],
    'thing': ['your phone', 'your diary', 'your search history', 'your gallery', 'your DMs', 'your Netflix history'],
    'action': ['stolen', 'broken', 'hidden', 'lied about', 'secretly loved', 'regretted doing', 'been caught doing', 'pretended to like'],
  };
  final socialTruthTpls = [
    'What is the most embarrassing thing you did at {event}?',
    'Have you ever {action} something belonging to {person}?',
    'If we opened {thing} right now, what is the worst thing we would find?',
    'What is the biggest lie you ever told {person}?',
    'Who is the last person you stalked on social media?',
    'Have you ever eavesdropped on {person}?',
    'What is the pettiest reason you stopped being friends with someone?',
    'Have you ever faked an illness to avoid {event}?',
    'What is the most awkward encounter you have had with {person}?',
    'Have you ever sent a text to the wrong person? What did it say?',
  ];

  final socialDareVars = {
    'target': ['the person to your right', 'the host', 'the quietest person here', 'your best friend', 'the person with the deepest voice', 'the first contact in your phone'],
    'action': ['sing a Bollywood song', 'do 10 pushups', 'do a funny dance', 'speak in a British accent', 'tell a bad joke', 'bark like a dog', 'act like a monkey'],
    'duration': ['10 seconds', '20 seconds', '1 minute', 'the rest of the round', 'the next 3 rounds'],
  };
  final socialDareTpls = [
    'Call {target} and {action} for {duration}.',
    'Message {target} saying "I have a secret" and don\'t reply for {duration}.',
    '{action} loudly for {duration}.',
    'Give a 30-second speech about why {target} is awesome.',
    'Let {target} send one text from your phone to anyone.',
    'Change your WhatsApp DP to a meme chosen by {target} for {duration}.',
    'Do your best impression of {target}.',
    'Speak only in rhymes for {duration}.',
  ];

  // ── DATING ──
  final datingTruthVars = {
    'person': ['your ex', 'your current crush', 'your first love', 'someone in this room', 'a friend\'s ex', 'a stranger'],
    'trait': ['looks', 'money', 'personality', 'humor', 'height', 'voice'],
    'action': ['kissed', 'dated', 'rejected', 'ghosted', 'stalked', 'cried over'],
  };
  final datingTruthTpls = [
    'What is the main reason you broke up with {person}?',
    'Have you ever {action} {person} and regretted it?',
    'Which is more important to you: {trait} or {trait}?',
    'What is your biggest red flag in a relationship?',
    'Have you ever cheated or been tempted to cheat on {person}?',
    'What is the most embarrassing thing you did to impress {person}?',
    'Have you ever used a dating app just for validation?',
    'What is the worst date you have ever been on?',
    'Do you still have feelings for {person}?',
    'Have you ever settled for someone because you were lonely?',
  ];
  final datingDareVars = {
    'target': ['your ex', 'your crush', 'the person you find most attractive here', 'a random contact', 'the host'],
    'action': ['send a flirty text', 'confess your love', 'ask for a date', 'send a heart emoji', 'say "I miss you"'],
  };
  final datingDareTpls = [
    'You must {action} to {target} right now.',
    'Let the group write a Tinder bio for you and use it for 24 hours.',
    'Show the group your last conversation with {target}.',
    'Give a romantic compliment to {target}.',
    'Roleplay a terrible first date with {target} for 1 minute.',
    'Rate {target}\'s dating profile out of 10 and explain why.',
    'Post a story tagging {target} with a heart.',
  ];

  // ── PERSONAL ──
  final personalTruthVars = {
    'emotion': ['cried', 'felt completely lost', 'been terrified', 'felt true joy', 'felt deeply ashamed'],
    'topic': ['your childhood', 'your career', 'your mental health', 'your family', 'your biggest failure'],
  };
  final personalTruthTpls = [
    'When was the last time you {emotion} and why?',
    'What is your deepest insecurity regarding {topic}?',
    'What is a secret you have never told anyone?',
    'Have you ever betrayed someone\'s trust completely?',
    'What is the biggest mistake you have made in {topic}?',
    'Do you think you are a good person? Why or why not?',
    'What is the most selfish thing you have ever done?',
    'What is a lie you tell yourself every day?',
  ];
  final personalDareVars = {
    'target': ['a family member', 'an old friend', 'someone you wronged', 'yourself'],
  };
  final personalDareTpls = [
    'Call {target} and apologize for something you did.',
    'Share a deeply embarrassing photo of yourself from 5 years ago.',
    'Tell the group your most embarrassing flaw.',
    'Show the group the last note you wrote in your Notes app.',
    'Confess something you are deeply ashamed of to the group.',
    'Let the group ask you one question you MUST answer honestly.',
  ];

  // ── NETWORKING ──
  final netTruthVars = {
    'person': ['your boss', 'a coworker', 'a competitor', 'your mentor'],
    'thing': ['your salary', 'your resume', 'your actual skills', 'a project'],
  };
  final netTruthTpls = [
    'Have you ever lied on {thing}?',
    'What is the worst thing you have said behind {person}\'s back?',
    'Have you ever taken credit for someone else\'s work?',
    'What is the biggest mistake you covered up at work?',
    'Would you step on {person} to get a promotion?',
    'Have you ever secretly dated {person}?',
  ];
  final netDareVars = {
    'target': ['your boss', 'a colleague on LinkedIn', 'a competitor'],
  };
  final netDareTpls = [
    'Endorse {target} on LinkedIn for a random useless skill.',
    'Send a completely professional email to {target} right now containing the word "banana".',
    'Show the group your last 5 work emails or messages.',
    'Post a highly motivational but completely meaningless quote on LinkedIn.',
  ];

  // ── ROAST ──
  final roastTruthVars = {
    'target': ['the person on your left', 'the host', 'the person talking the most', 'yourself'],
    'trait': ['fashion sense', 'voice', 'intelligence', 'dating history', 'social media presence'],
  };
  final roastTruthTpls = [
    'What is the worst thing about {target}\'s {trait}?',
    'If {target} were a cartoon character, who would they be and why?',
    'What is the most annoying habit {target} has?',
    'Why is {target} single?',
    'What is the most cringe-worthy thing about {target}?',
  ];
  final roastDareVars = {
    'target': ['the person on your left', 'the host', 'the person talking the most'],
  };
  final roastDareTpls = [
    'Roast {target} non-stop for 45 seconds.',
    'Imitate {target}\'s worst habit until someone guesses what it is.',
    'Let {target} roast you for 1 minute while you stay completely silent.',
    'Find {target}\'s oldest Instagram post and leave a cringe comment.',
  ];

  // ── DEEP TALK ──
  final deepTruthVars = {
    'topic': ['death', 'love', 'purpose', 'regret', 'happiness'],
  };
  final deepTruthTpls = [
    'What is your biggest fear regarding {topic}?',
    'If you died tomorrow, what would be your biggest regret?',
    'What do you think is the true meaning of {topic}?',
    'Have you ever felt completely empty? When?',
    'What is a childhood trauma that still affects you today?',
    'What is the hardest lesson life has taught you?',
  ];
  final deepDareVars = {
    'target': ['the group', 'yourself in the mirror', 'the person you trust most here'],
  };
  final deepDareTpls = [
    'Give a 2-minute speech to {target} about your biggest life regret.',
    'Look at {target} and confess your deepest insecurity.',
    'Share a poem or quote that perfectly describes your current mental state.',
    'Tell {target} what you truly value in life.',
  ];

  // ── 18+ ──
  final adultTruthVars = {
    'place': ['a public place', 'a car', 'a party', 'work', 'school'],
    'person': ['an ex', 'a stranger', 'a friend\'s partner', 'someone older'],
  };
  final adultTruthTpls = [
    'What is the most scandalous thing you have done in {place}?',
    'Have you ever had a completely inappropriate fantasy about {person}?',
    'What is your highest body count in a single year?',
    'Have you ever sent a risqué text to the wrong person?',
    'What is your biggest turn-on and turn-off?',
    'Have you ever been caught in the act? Tell the story.',
    'What is the boldest move you have ever made on {person}?',
  ];
  final adultDareVars = {
    'target': ['the most attractive person here', 'the host', 'a random contact', 'an ex'],
  };
  final adultDareTpls = [
    'Send a highly suggestive text to {target}.',
    'Describe your ideal intimate night in extreme detail.',
    'Let the group look at the hidden photos folder on your phone for 10 seconds.',
    'Give a lap dance to a pillow while maintaining eye contact with the camera/group.',
    'Moan loudly for 10 seconds.',
    'Describe the physical features of {target} that you find most attractive.',
  ];

  final Map<String, List<String>> allTruths = {
    'Social': fill(socialTruthTpls, socialTruthVars, count),
    'Dating': fill(datingTruthTpls, datingTruthVars, count),
    'Personal': fill(personalTruthTpls, personalTruthVars, count),
    'Networking': fill(netTruthTpls, netTruthVars, count),
    'Roast': fill(roastTruthTpls, roastTruthVars, count),
    'Deep Talk': fill(deepTruthTpls, deepTruthVars, count),
    '18+': fill(adultTruthTpls, adultTruthVars, count),
  };

  final Map<String, List<String>> allDares = {
    'Social': fill(socialDareTpls, socialDareVars, count),
    'Dating': fill(datingDareTpls, datingDareVars, count),
    'Personal': fill(personalDareTpls, personalDareVars, count),
    'Networking': fill(netDareTpls, netDareVars, count),
    'Roast': fill(roastDareTpls, roastDareVars, count),
    'Deep Talk': fill(deepDareTpls, deepDareVars, count),
    '18+': fill(adultDareTpls, adultDareVars, count),
  };

  sink.writeln("  static const Map<String, List<String>> truths = {");
  allTruths.forEach((k, v) {
    sink.writeln("    '$k': [");
    for (var q in v) {
      sink.writeln("      '${q.replaceAll("'", "\\'")}',");
    }
    sink.writeln("    ],");
  });
  sink.writeln("  };");

  sink.writeln("  static const Map<String, List<String>> dares = {");
  allDares.forEach((k, v) {
    sink.writeln("    '$k': [");
    for (var q in v) {
      sink.writeln("      '${q.replaceAll("'", "\\'")}',");
    }
    sink.writeln("    ],");
  });
  sink.writeln("  };");
  
  sink.writeln("}");
  await sink.close();
  print("Data generated!");
}


