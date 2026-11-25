import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/study_note.dart';
void main(){
 test('legacy free notes default to unlocked without private PDF',(){
  final note=StudyNote.fromJson({'id':1,'title':'Free','content':'Text'});
  expect(note.locked,false);expect(note.premiumOnly,false);expect(note.privatePdf,false);expect(note.content,'Text');
 });
 test('locked preview exposes title and flag, without content or file',(){
  final note=StudyNote.fromJson({'id':2,'title':'Premium','locked':true,'premium_only':true,'private_pdf':false});
  expect(note.locked,true);expect(note.premiumOnly,true);expect(note.content,isNull);expect(note.fileUrl,isNull);
 });
 test('authorized private PDF is a capability, not a public attachment URL',(){
  final note=StudyNote.fromJson({'id':3,'title':'Premium PDF','locked':false,'premium_only':true,'private_pdf':true});
  expect(note.privatePdf,true);expect(note.fileUrl,isNull);
 });
}
