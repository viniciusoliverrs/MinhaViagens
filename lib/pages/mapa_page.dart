import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaPage extends StatefulWidget {
  String? viagemId;
  MapaPage(this.viagemId);

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _marcadores = {};
  CameraPosition _posicaoCamera =
      const CameraPosition(target: LatLng(-23.562436, -46.655005), zoom: 18);
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarMarcador(LatLng latLng) async {
    List<Placemark> listaEnderecos =
        await placemarkFromCoordinates(latLng.latitude, latLng.longitude);

    if (listaEnderecos.isNotEmpty) {
      Placemark endereco = listaEnderecos[0];
      String? rua = endereco.thoroughfare;

      Marker marcador = Marker(
          markerId: MarkerId("marcador-${latLng.latitude}-${latLng.longitude}"),
          position: latLng,
          infoWindow: InfoWindow(title: rua));

      setState(() {
        _marcadores.add(marcador);
        Map<String, dynamic> viagem = {};
        viagem["titulo"] = rua;
        viagem["latitude"] = latLng.latitude;
        viagem["longitude"] = latLng.longitude;
        _db.collection("viagens").add(viagem);
      });
    }
  }

  _movimentarCamera() async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(_posicaoCamera));
  }

  _adicionarListenerLocalizacao() async {
    late bool serviceEnabled;
    late LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    // var position = await Geolocator.getCurrentPosition(
    //     desiredAccuracy: LocationAccuracy.high);
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );
    StreamSubscription<Position> positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position? position) {
      if (position != null) {
        // _adicionarMarcador(LatLng(position.latitude, position.longitude));
        setState(() {
          _posicaoCamera = CameraPosition(
              bearing: 10,
              tilt: 70,
              target: LatLng(position.latitude, position.longitude),
              zoom: 20);
          _movimentarCamera();
        });
      }
    });
  }

  _recuperaViagemPorId(String? viagemId) async {
    if (viagemId != null) {
      //exibir marcador para id viagem
      DocumentSnapshot documentSnapshot =
          await _db.collection("viagens").doc(viagemId).get();

      Map<String, dynamic> dados = documentSnapshot.data()! as Map<String, dynamic>;

      // String titulo = dados["titulo"].toString();
      LatLng latLng = LatLng(dados["latitude"], dados["longitude"]);

      setState(() {
        Marker marcador = Marker(
            markerId:
                MarkerId("marcador-${dados['latitude']}-${dados['longitude']}"),
            position: latLng,
            infoWindow: InfoWindow(title: dados["titulo"]));

        _marcadores.add(marcador);
        _posicaoCamera = CameraPosition(target: latLng, zoom: 18);
        _movimentarCamera();
      });
    } else {
      _adicionarListenerLocalizacao();
    }
  }

  @override
  void initState() {
    super.initState();

    //Recupera viagem pelo ID
    _recuperaViagemPorId(widget.viagemId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapa"),
      ),
      body: Container(
        child: GoogleMap(
          markers: _marcadores,
          mapType: MapType.normal,
          initialCameraPosition: _posicaoCamera,
          onMapCreated: _onMapCreated,
          onLongPress: _adicionarMarcador,
        ),
      ),
    );
  }
}
