import 'package:stomp_dart/stomp_frame.dart';
import 'package:stomp_dart/stomp_parser.dart';
import 'package:test/test.dart';

void main() {
  group('StompParser', () {
    test('can parse basic message', () {
      final msg = "MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00";

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 2);
        expect(frame.headers.containsKey('destination'), isTrue);
        expect(frame.headers.containsKey('message-id'), isTrue);
        expect(frame.headers['destination'], 'foo');
        expect(frame.headers['message-id'], '456');
        expect(frame.body, isEmpty);
      }, count: 1);

      final parser = StompParser(callback);

      parser.parseData(msg);
    });

    test('does not unescape headers (v1.0)', () {
      final msg = "MESSAGE\ndesti\\nnation:f\\noo\nmessage-id:456\n\n\x00";

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 2);
        expect(frame.headers.containsKey('desti\\nnation'), isTrue);
        expect(frame.headers.containsKey('message-id'), isTrue);
        expect(frame.headers['desti\\nnation'], 'f\\noo');
        expect(frame.headers['message-id'], '456');
        expect(frame.body, isEmpty);
      }, count: 1);

      final parser = StompParser(callback);

      parser.parseData(msg);
    });

    test('fails on unescaped header values (v1.0)', () {
      final msg = "MESSAGE\ndesti\\nnation:f\noo\nmessage-id:456\n\n\x00";

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 2);
        expect(frame.headers.containsKey('desti\\nnation'), isTrue);
        expect(frame.headers.containsKey('oo\nmessage-id'), isTrue);
        expect(frame.headers['desti\\nnation'], 'f');
        expect(frame.headers['oo\nmessage-id'], '456');
        expect(frame.body, isEmpty);
      }, count: 1);

      final parser = StompParser(callback);

      parser.parseData(msg);
    });

    test('does unescape header keys and values (^v1.1)', () {
      final msg = "MESSAGE\ndesti\\nnation:f\\noo\nmessage-id:456\n\n\x00";

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 2);
        expect(frame.headers.containsKey('desti\nnation'), isTrue);
        expect(frame.headers.containsKey('message-id'), isTrue);
        expect(frame.headers['desti\nnation'], 'f\noo');
        expect(frame.headers['message-id'], '456');
        expect(frame.body, isEmpty);
      }, count: 1);

      final parser = StompParser(callback);

      parser.escapeHeaders = true;

      parser.parseData(msg);
    });

    test('supports escaped colons in headers (^v1.1)', () {
      final msg = "MESSAGE\ndestination\\cbar:foo\\cbar\nmessage-id:456\n\n\x00";

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 2);
        expect(frame.headers.containsKey('destination:bar'), isTrue);
        expect(frame.headers.containsKey('message-id'), isTrue);
        expect(frame.headers['destination:bar'], 'foo:bar');
        expect(frame.headers['message-id'], '456');
        expect(frame.body, isEmpty);
      }, count: 1);

      final parser = StompParser(callback);

      parser.escapeHeaders = true;

      parser.parseData(msg);
    });

    test('correctly serializes a stomp frame unescaped', () {
      final stringFrame = 'SEND\ndestination:/path/to/foo\ncontent-type:text/plain\n\nThis is a body\x00';
      final frame = StompFrame(command: 'SEND', body: 'This is a body', headers: {'destination': '/path/to/foo', 'content-type': 'text/plain'});

      final parser = StompParser(null);

      final serializedFrame = parser.serializeFrameToString(frame);

      expect(serializedFrame, stringFrame);
    });

    test('correctly serializes a stomp frame escaped', () {
      final stringFrame = 'SEND\ndesti\\nnation:/path/to/foo\ncontent-type:te\\nxt/plain\n\nThis is a body\x00';
      final frame = StompFrame(command: 'SEND', body: 'This is a body', headers: {'desti\nnation': '/path/to/foo', 'content-type': 'te\nxt/plain'});

      final parser = StompParser(null);
      parser.escapeHeaders = true;

      final serializedFrame = parser.serializeFrameToString(frame);

      expect(serializedFrame, stringFrame);
    });

    test('can parse frame with empty header', () {
      final msg = "MESSAGE\n\nThis is a body\x00";

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 0);
        expect(frame.body, 'This is a body');
      }, count: 1);

      final parser = StompParser(callback);

      parser.escapeHeaders = true;

      parser.parseData(msg);
    });

    test('can parse frame with empty header and body', () {
      final msg = "MESSAGE\n\n\x00";

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 0);
        expect(frame.body, isEmpty);
      }, count: 1);

      final parser = StompParser(callback);

      parser.escapeHeaders = true;

      parser.parseData(msg);
    });

    test('respects content-length when parsing', () {
      final msg = "MESSAGE\ncontent-length:10\n\nThis is a body longer than 10 bytes\x00";

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 1);
        expect(frame.headers['content-length'], '10');
        expect(frame.body, 'This is a ');
      }, count: 1);

      final parser = StompParser(callback);

      parser.parseData(msg);
    });

    test('fails silently on wrong content-length', () {
      final msg = "MESSAGE\ncontent-length:10\n\nThis is\x00";

      var callback = expectAsync1((frame) {}, count: 0);

      final parser = StompParser(callback);

      parser.parseData(msg);
    });

    test('can parse ping message', () {
      dynamic onFrame = expectAsync1((frame) {}, count: 0);
      dynamic onPing = expectAsync0(() => null, count: 1);

      final parser = StompParser(onFrame, onPing);

      parser.parseData("\n");
    });

    test('accepts ping/frames with carriage return', () {
      dynamic onFrame = expectAsync1((frame) {}, count: 1);
      dynamic onPing = expectAsync0(() => null, count: 2);

      final parser = StompParser(onFrame, onPing);

      parser.parseData("\r\n");
      parser.parseData("\r\nMESSAGE\r\ndestination:foo\r\nmessage-id:456\r\n\r\n\x00");
    });

    test('can parse multiple messages seperatley', () {
      final msg = "MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00";
      final msg2 = "MESSAGE\ndestination:bar\nmessage-id:123\n\nThis is a body\x00";

      int n = 0;
      dynamic onFrame = expectAsync1((frame) {
        if (n == 0) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('destination'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['destination'], 'foo');
          expect(frame.headers['message-id'], '456');
          expect(frame.body, isEmpty);
        } else {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('destination'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['destination'], 'bar');
          expect(frame.headers['message-id'], '123');
          expect(frame.body, 'This is a body');
        }
        n++;
      }, count: 2);

      final parser = StompParser(onFrame);

      parser.parseData(msg);
      parser.parseData(msg2);
    });

    test('can parse multiple messages at once', () {
      final msg = "MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00";
      final msg2 = "MESSAGE\ndestination:bar\nmessage-id:123\n\nThis is a body\x00";

      int n = 0;
      dynamic onFrame = expectAsync1((frame) {
        if (n == 0) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('destination'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['destination'], 'foo');
          expect(frame.headers['message-id'], '456');
          expect(frame.body, isEmpty);
        } else {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('destination'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['destination'], 'bar');
          expect(frame.headers['message-id'], '123');
          expect(frame.body, 'This is a body');
        }
        n++;
      }, count: 2);

      final parser = StompParser(onFrame);

      parser.parseData(msg + msg2);
    });
  });
}