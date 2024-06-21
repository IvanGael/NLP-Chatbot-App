// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:convert';

import 'package:lottie/lottie.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? iconUrl;
  final List<Map<String, dynamic>>? forecastData;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.iconUrl,
    this.forecastData,
  });
}

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  _ChatBotScreenState createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  late Position position;
  bool isGettingResponse = false;
  String? cityName;

  late ScrollController _scrollController;

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  _getCurrentLocationAsync() async {
    try {
      position = await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAsync();

    _scrollController = ScrollController();
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: _controller.text, isUser: true));
      isGettingResponse = true;
    });

    final userMessage = _controller.text;
    _controller.clear();

    String cityNameFromMessage;
    if (userMessage.toLowerCase().contains("in")) {
      final splitMessage = userMessage.toLowerCase().split("in");
      cityNameFromMessage =
          splitMessage[1].trim().replaceAll(RegExp(r'[^\w\s]+'), '');
    } else {
      cityNameFromMessage = "";
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/chat'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'message': userMessage,
          'lat': position.latitude,
          'lon': position.longitude,
          'city_name': cityNameFromMessage,
        }),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        String botResponse = '';
        String? iconUrl;
        List<Map<String, dynamic>>? forecastData;

        if (data['type'] == 'current') {
          botResponse = '${data['weather']['name']}\n'
              'Get ready for ${data['weather']['temp']}°C weather and ${data['weather']['humidity']}% humidity\n'
              'Weather: ${data['weather']['description']}\n\n'
              '${data['weather']['recommendation']}';
          iconUrl = data['weather']['icon'];
        } else if (data['type'] == 'forecast') {
          forecastData = [];
          data['forecast'].forEach((day, dayForecast) {
            for (var forecast in dayForecast) {
              forecastData!.add({
                'datetime': forecast['datetime'],
                'temp': forecast['temp'],
                'description': forecast['description'],
                'icon': forecast['icon'],
              });
            }
          });
          botResponse = 'Forecast for ${data['location']}:\n';
        } else {
          botResponse = data['message'] ?? data['error'] ?? 'Unknown response';
        }


        setState(() {
          _messages.add(ChatMessage(
            text: botResponse,
            isUser: false,
            iconUrl: iconUrl,
            forecastData: forecastData,
          ));
        });

        await Future.delayed(const Duration(seconds: 4), (){
          setState(() {
            isGettingResponse = false;
          });
        });

        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 800,
            duration: const Duration(seconds: 1),
            curve: Curves.fastOutSlowIn);
      } else {
        setState(() {
          _messages.add(ChatMessage(
              text: 'Failed to get response', isUser: false));
          isGettingResponse = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
        isGettingResponse = false;
      });
    }
  }

  Widget _buildMessage(ChatMessage message, int index) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: message.isUser
              ? Colors.blue[100]
              : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: isGettingResponse == true && index == _messages.length - 1
            ? Center(
                child: SpinKitThreeInOut(
                  size: 20,
                  itemBuilder: (BuildContext context, int index) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? Colors.white
                            : Colors.black.withOpacity(0.4),
                      ),
                    );
                  },
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.iconUrl != null)
                    Image.network(message.iconUrl!, width: 70, height: 70),
                  Text(
                    message.text,
                    style: TextStyle(
                        color: message.isUser
                            ? Colors.blue[800]
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  if (message.forecastData != null)
                    _buildForecast(message.forecastData!),
                ],
              ),
      ),
    );
  }

  Widget _buildForecast(List<Map<String, dynamic>> forecastData) {
    return Column(
      children: forecastData.map((forecast) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(
                forecast['datetime'],
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 10),
              Image.network(forecast['icon'], width: 30, height: 30),
              const SizedBox(width: 10),
              Text(
                '${forecast['temp']}°C',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: Text(
                  forecast['description'],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CloudMate°',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 3),
        ),
        centerTitle: true,
        elevation: 1,
        shadowColor: Colors.black,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurpleAccent, Colors.tealAccent.shade200],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurpleAccent, Colors.purple.shade200],
          ),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            "assets/bot.json",
                            width: 100,
                            height: 100
                          ),
                          const Text(
                            "Get weather insights",
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _messages.length,
                      controller: _scrollController,
                      itemBuilder: (context, index) {
                        return _buildMessage(_messages[index], index);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask something',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.white)
                    ),
                    icon: Icon(Icons.outbond, color: Colors.blue.shade800),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
