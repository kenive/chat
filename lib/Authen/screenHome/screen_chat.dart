import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
//import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ChatRoom extends StatefulWidget {
  final Map<String, dynamic> userMap;
  final String chatRoomId;

  ChatRoom({required this.chatRoomId, required this.userMap});

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  final TextEditingController _message = TextEditingController();
  final ScrollController controller = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  File? imageFile;

  void scrollToBottom() {
    if (controller.hasClients) {
      final position = controller.position.maxScrollExtent;
      controller.animateTo(position,
          duration: const Duration(milliseconds: 100), curve: Curves.bounceOut);
    }
    print(123);
  }

  // Future getImage() async {
  //   ImagePicker _picker = ImagePicker();

  //   await _picker.pickImage(source: ImageSource.gallery).then((xFile) {
  //     if (xFile != null) {
  //       imageFile = File(xFile.path);
  //       uploadImage();
  //     }
  //   });
  // }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scrollToBottom();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future uploadImage() async {
    String fileName = Uuid().v1();
    int status = 1;

    await _firestore
        .collection('chatroom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .doc(fileName)
        .set({
      "sendby": _auth.currentUser!.displayName,
      "message": "",
      "type": "img",
      "time": FieldValue.serverTimestamp(),
    });

    var ref =
        FirebaseStorage.instance.ref().child('images').child("$fileName.jpg");

    var uploadTask = await ref.putFile(imageFile!).catchError((error) async {
      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc(fileName)
          .delete();

      status = 0;
    });

    if (status == 1) {
      String imageUrl = await uploadTask.ref.getDownloadURL();

      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc(fileName)
          .update({"message": imageUrl});

      print(imageUrl);
    }
  }

  Future<void> onSendMessage() async {
    if (_message.text.isNotEmpty) {
      Map<String, dynamic> messages = {
        "sendby": _auth.currentUser!.displayName,
        "message": _message.text,
        "type": "text",
        "time": FieldValue.serverTimestamp(),
      };

      _message.clear();
      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .add(messages);
    } else {
      print("Enter Some Text");
    }
  }

  int count = 0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () async {
        if (count == 0) {
          scrollToBottom();
        }
        count++;
        print('object');

        Focus.of(context).unfocus();
        // if (controller.position.maxScrollExtent.isNaN) {
        //   scrollToBottom();
        // }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection("users")
                .doc(widget.userMap['uid'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                return Container(
                  child: Column(
                    children: [
                      Text(widget.userMap['name']),
                      Text(
                        snapshot.data!['status'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              } else {
                return Container();
              }
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SizedBox(
                height: size.height / 1.25,
                width: size.width,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('chatroom')
                      .doc(widget.chatRoomId)
                      .collection('chats')
                      .orderBy("time", descending: false)
                      .snapshots(),
                  builder: (BuildContext context,
                      AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.data != null) {
                      scrollToBottom();
                      return ListView.builder(
                        controller: controller,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> map = snapshot.data!.docs[index]
                              .data() as Map<String, dynamic>;
                          // return messages(size, map, context);
                          return map['type'] == "text"
                              ? Container(
                                  width: size.width,
                                  alignment: map['sendby'] ==
                                          _auth.currentUser!.displayName
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 14),
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: Colors.blue,
                                    ),
                                    child: Text(
                                      map['message'],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  height: size.height / 2.5,
                                  width: size.width,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 5, horizontal: 5),
                                  alignment: map['sendby'] ==
                                          _auth.currentUser!.displayName
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ShowImage(
                                          imageUrl: map['message'],
                                        ),
                                      ),
                                    ),
                                    child: Container(
                                      height: size.height / 2.5,
                                      width: size.width / 2,
                                      decoration:
                                          BoxDecoration(border: Border.all()),
                                      alignment: map['message'] != ""
                                          ? null
                                          : Alignment.center,
                                      child: map['message'] != ""
                                          ? Image.network(
                                              map['message'],
                                              fit: BoxFit.cover,
                                            )
                                          : CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                        },
                      );
                    } else {
                      return Container();
                    }
                  },
                ),
              ),
            ),
            Container(
              height: size.height / 10,
              width: size.width,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: size.height / 12,
                width: size.width / 1.1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: size.height / 17,
                      width: size.width / 1.3,
                      child: TextFormField(
                        controller: _message,
                        decoration: InputDecoration(
                            suffixIcon: IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.photo),
                            ),
                            hintText: "Send Message",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            )),
                      ),
                    ),
                    IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () async {
                          await onSendMessage();
                          scrollToBottom();
                        }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShowImage extends StatelessWidget {
  final String imageUrl;

  const ShowImage({required this.imageUrl, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        color: Colors.black,
        child: Image.network(imageUrl),
      ),
    );
  }
}

//
