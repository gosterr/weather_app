import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/weather_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _loadWeatherData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadWeatherData() async {
    await Future.microtask(() =>
        Provider.of<WeatherService>(context, listen: false).getCurrentLocation());
    _controller.forward();
  }

  String _getWeatherIcon(String? condition, {DateTime? time}) {
    if (condition == null) return '🌤️';
    
    // Get current time if not provided
    time ??= DateTime.now();
    final isNight = time.hour < 6 || time.hour >= 18;
    
    condition = condition.toLowerCase();
    if (condition.contains('clear')) {
      return isNight ? '🌕' : '☀️';
    }
    if (condition.contains('cloud')) {
      return isNight ? '☁️' : '⛅';
    }
    if (condition.contains('rain')) return '🌧️';
    if (condition.contains('snow')) return '🌨️';
    if (condition.contains('thunderstorm')) return '⛈️';
    if (condition.contains('drizzle')) return '🌦️';
    if (condition.contains('mist') || condition.contains('fog')) return '🌫️';
    return isNight ? '🌕' : '🌤️';
  }

  Widget _buildHourlyForecast(List<dynamic> forecast) {
    // Get the next 8 forecasts (24 hours with 3-hour intervals)
    final hourlyForecasts = forecast.take(8).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 48) / 4.5; // Show 4.5 items at a time
    
    return Container(
      height: 130,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: hourlyForecasts.length,
        itemBuilder: (context, index) {
          final item = hourlyForecasts[index];
          final time = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          final isNow = index == 0;
          
          return Container(
            width: itemWidth,
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == hourlyForecasts.length - 1 ? 0 : 0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: isNow ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isNow ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  child: Text(
                    isNow ? 'Now' : DateFormat('h:mm a').format(time),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: isNow ? 14 : 13,
                      fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getWeatherIcon(item['weather']?[0]?['main'], time: time),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(item['main']?['temp'] ?? 0).round()}°',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyForecast(List<dynamic> forecast) {
    // Group forecast by day
    final Map<String, List<dynamic>> dailyForecasts = {};
    for (var item in forecast) {
      final date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      if (!dailyForecasts.containsKey(dateKey)) {
        dailyForecasts[dateKey] = [];
      }
      dailyForecasts[dateKey]!.add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 16),
          child: Text(
            '5-DAY FORECAST',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...dailyForecasts.entries.take(5).map((entry) {
          final date = DateTime.parse(entry.key);
          final forecasts = entry.value;
          
          // Calculate min and max temperatures for the day
          double minTemp = double.infinity;
          double maxTemp = double.negativeInfinity;
          String? weatherCondition;
          DateTime? forecastTime;
          
          for (var forecast in forecasts) {
            final temp = (forecast['main']?['temp'] ?? 0).toDouble();
            if (temp < minTemp) minTemp = temp;
            if (temp > maxTemp) {
              maxTemp = temp;
              weatherCondition = forecast['weather']?[0]?['main'];
              forecastTime = DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000);
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    DateFormat('EEEE').format(date),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      _getWeatherIcon(weatherCondition, time: forecastTime),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${minTemp.round()}° / ${maxTemp.round()}°',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSearchBar() {
    final TextEditingController controller = TextEditingController();
    final FocusNode focusNode = FocusNode();
    final LayerLink layerLink = LayerLink();
    bool isOverlayVisible = false;
    List<Map<String, dynamic>> suggestions = [];
    OverlayEntry? overlayEntry;

    void hideOverlay() {
      overlayEntry?.remove();
      overlayEntry = null;
      isOverlayVisible = false;
    }

    void showOverlay() {
      if (!isOverlayVisible) {
        final overlay = Overlay.of(context);
        final renderBox = context.findRenderObject() as RenderBox;
        final size = renderBox.size;

        overlayEntry = OverlayEntry(
          builder: (context) => Positioned(
            width: size.width - 48,
            child: CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 60),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (suggestions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_off_rounded,
                                    color: Colors.white60,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No cities found',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white60,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: suggestions.length,
                                itemBuilder: (context, index) {
                                  final suggestion = suggestions[index];
                                  final cityName = suggestion['name'] as String;
                                  final country = suggestion['country'] as String;
                                  final state = suggestion['state'] as String?;
                                  
                                  return TweenAnimationBuilder<double>(
                                    duration: Duration(milliseconds: 200 + (index * 50)),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    builder: (context, value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: Opacity(
                                          opacity: value,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: InkWell(
                                      onTap: () {
                                        controller.text = cityName;
                                        hideOverlay();
                                        final weatherService = Provider.of<WeatherService>(context, listen: false);
                                        weatherService.searchCityByCoordinates(
                                          suggestion['lat'] as double,
                                          suggestion['lon'] as double,
                                        );
                                        focusNode.unfocus();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.white.withOpacity(0.1),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            if (suggestion['isEgyptian'] == true)
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                margin: const EdgeInsets.only(right: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                              ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    cityName,
                                                    style: GoogleFonts.spaceGrotesk(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: suggestion['isEgyptian'] == true
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    state != null ? '$state, $country' : country,
                                                    style: GoogleFonts.spaceGrotesk(
                                                      color: suggestion['isEgyptian'] == true
                                                          ? Colors.white70
                                                          : Colors.white60,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Colors.white.withOpacity(0.3),
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        overlay.insert(overlayEntry!);
        isOverlayVisible = true;
      }
    }

    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              Future.delayed(const Duration(milliseconds: 200), () {
                hideOverlay();
              });
            }
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Search city...',
              hintStyle: GoogleFonts.spaceGrotesk(
                color: Colors.white60,
                fontSize: 16,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.white60),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white60, size: 20),
                      onPressed: () {
                        controller.clear();
                        hideOverlay();
                      },
                    ),
                  Container(
                    height: 24,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white60),
                    onPressed: () {
                      controller.clear();
                      hideOverlay();
                      focusNode.unfocus();
                      _loadWeatherData();
                    },
                  ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (value) async {
              if (value.toLowerCase() == "gamsah") {
                controller.text = "faraskur";
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: "faraskur".length),
                );
                final weatherService = Provider.of<WeatherService>(context, listen: false);
                suggestions = await weatherService.getCitySuggestions("faraskur");
                if (suggestions.isNotEmpty) {
                  showOverlay();
                }
              } else if (value.length >= 2) {
                final weatherService = Provider.of<WeatherService>(context, listen: false);
                suggestions = await weatherService.getCitySuggestions(value);
                if (suggestions.isNotEmpty || value.length >= 3) {
                  showOverlay();
                }
              } else {
                hideOverlay();
              }
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                Provider.of<WeatherService>(context, listen: false).searchCity(value);
                hideOverlay();
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<WeatherService>(
        builder: (context, weatherService, child) {
          if (weatherService.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Fetching weather data...',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (weatherService.error != null) {
            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              weatherService.error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadWeatherData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (weatherService.currentWeather == null) {
            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'No weather data available',
                        style: GoogleFonts.spaceGrotesk(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final weather = weatherService.currentWeather!;
          final forecast = weatherService.forecast;
          final currentTime = DateTime.fromMillisecondsSinceEpoch(weather['dt'] * 1000);

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade900,
                    Colors.black,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              weather['name'] ?? 'Unknown Location',
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              DateFormat('EEEE, d MMMM').format(currentTime),
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 16,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _getWeatherIcon(weather['weather']?[0]?['main'], time: currentTime),
                                        style: const TextStyle(fontSize: 48),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${(weather['main']?['temp'] ?? 0).round()}',
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 96,
                                          fontWeight: FontWeight.w200,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '°C',
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w200,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    (weather['weather']?[0]?['description'] ?? '').toString().toUpperCase(),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 20,
                                      color: Colors.white70,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildWeatherInfo(
                                      'Humidity',
                                      '${weather['main']?['humidity'] ?? 0}%',
                                      Icons.water_drop_outlined,
                                    ),
                                    _buildWeatherInfo(
                                      'Wind',
                                      '${weather['wind']?['speed'] ?? 0} m/s',
                                      Icons.air,
                                    ),
                                    _buildWeatherInfo(
                                      'Feels Like',
                                      '${(weather['main']?['feels_like'] ?? 0).round()}°C',
                                      Icons.thermostat,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (forecast != null && forecast.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 24, right: 24, top: 32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'HOURLY FORECAST',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildHourlyForecast(forecast),
                                    _buildDailyForecast(forecast),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeatherInfo(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 
