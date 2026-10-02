import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:personal_memory_os/core/services/share_source.dart';

SharedMediaFile item(String path, SharedMediaType type) =>
    SharedMediaFile(path: path, type: type);

void main() {
  test('shared text is returned trimmed', () {
    expect(sharedTextFrom([item('  AWS Hackathon Oct 4  ', SharedMediaType.text)]),
        'AWS Hackathon Oct 4');
  });

  test('text and url items are joined, in order', () {
    expect(
      sharedTextFrom([
        item('Register by Oct 1', SharedMediaType.text),
        item('https://example.com/hack', SharedMediaType.url),
      ]),
      'Register by Oct 1\nhttps://example.com/hack',
    );
  });

  test('images, files and blank text are ignored', () {
    expect(sharedTextFrom([item('/tmp/a.jpg', SharedMediaType.image)]), isNull);
    expect(sharedTextFrom([item('/tmp/a.pdf', SharedMediaType.file)]), isNull);
    expect(sharedTextFrom([item('   ', SharedMediaType.text)]), isNull);
    expect(sharedTextFrom([]), isNull);
  });

  test('a mix keeps only the text', () {
    expect(
      sharedTextFrom([
        item('/tmp/a.jpg', SharedMediaType.image),
        item('Workshop Oct 12', SharedMediaType.text),
      ]),
      'Workshop Oct 12',
    );
  });

  test('NoShareSource shares nothing', () async {
    expect(await NoShareSource().initialText(), isNull);
    expect(await NoShareSource().texts.isEmpty, isTrue);
  });
}
