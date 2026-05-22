import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de Colores de la Marca (Inspirada en el logotipo oficial)
  static const Color slate900 = Color(0xFF0A1618); // Fondo Oscuro Petrol/Teal profundo
  static const Color slate800 = Color(0xFF132528); // Tarjetas/Superficie Oscura Petrol
  static const Color slate700 = Color(0xFF1D3B3E); // Bordes y Divisores
  static const Color slate400 = Color(0xFF7CA1A6); // Texto secundario / Muted Teal
  static const Color slate50 = Color(0xFFEAF4F5);  // Texto principal claro / Sky Off-White
  
  static const Color mintGreen = Color(0xFF0C828A);    // Teal primario de la marca (logo Pet-Tit)
  static const Color goldChampagne = Color(0xFFE8962B); // Ámbar cálido (blob naranja del logo)
  static const Color skyBlue = Color(0xFF8AD4E2);      // Azul cielo (flor del logo)
  static const Color peachCream = Color(0xFFF5D08A);   // Durazno crema (blob suave del logo)
  static const Color coralRed = Color(0xFFEF4444);     // Color de Alerta / Error

  // ── Tokens Semánticos — Tema Claro (alineados con logo Pet-Tit Resort) ──────
  static const Color background = Color(0xFFFAF8F3);    // Crema cálido — fondo principal
  static const Color surface = Colors.white;              // Blanco puro — tarjetas/paneles
  static const Color surfaceVariant = Color(0xFFEEF8F7); // Teal wash suave — chips/hover
  static const Color border = Color(0xFFCFE5E3);          // Borde teal claro
  static const Color textPrimary = Color(0xFF0D2B2E);    // Teal casi negro — texto principal
  static const Color textSecondary = Color(0xFF3E6669);   // Teal medio — subtítulos
  static const Color textMuted = Color(0xFF7FA4A8);       // Teal apagado — helper text

  /// Genera la configuración de Tema Oscuro Premium
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: mintGreen,
      scaffoldBackgroundColor: slate900,
      
      // Esquema de colores M3
      colorScheme: const ColorScheme.dark(
        primary: mintGreen,
        secondary: goldChampagne,
        tertiary: skyBlue,
        surface: slate800,
        error: coralRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: slate50,
      ),

      // Tipografía Fredoka para Títulos (Redondeada y Amigable) y Quicksand para Textos Generales
      textTheme: TextTheme(
        displayLarge: GoogleFonts.fredoka(fontSize: 32, fontWeight: FontWeight.bold, color: slate50),
        displayMedium: GoogleFonts.fredoka(fontSize: 26, fontWeight: FontWeight.bold, color: slate50),
        titleLarge: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.w600, color: slate50),
        titleMedium: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600, color: slate50),
        bodyLarge: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.normal, color: slate50),
        bodyMedium: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.normal, color: slate400),
        labelLarge: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.bold, color: mintGreen),
      ),

      // Estilo de los TextFields (Glassmorphism Inputs)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: slate800.withOpacity(0.5),
        hintStyle: GoogleFonts.quicksand(color: slate400, fontSize: 14),
        labelStyle: GoogleFonts.quicksand(color: slate50, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: slate700.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: slate700.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: mintGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: coralRed),
        ),
      ),

      // Estilo de los Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mintGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.fredoka(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Estilo de las Tarjetas
      cardTheme: CardThemeData(
        color: slate800,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: slate700.withOpacity(0.2)),
        ),
      ),
    );
  }

  /// Tema Claro oficial — basado en paleta logo Pet-Tit Resort
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: mintGreen,
      scaffoldBackgroundColor: background,

      colorScheme: const ColorScheme.light(
        primary: mintGreen,
        secondary: goldChampagne,
        tertiary: skyBlue,
        surface: surface,
        error: coralRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        outline: border,
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.fredoka(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: GoogleFonts.fredoka(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.normal, color: textSecondary),
        bodyMedium: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.normal, color: textMuted),
        labelLarge: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.bold, color: mintGreen),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.quicksand(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.quicksand(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: mintGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: coralRed),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mintGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: mintGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: mintGreen,
        unselectedLabelColor: textMuted,
        indicatorColor: mintGreen,
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: mintGreen.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: mintGreen,
        labelStyle: GoogleFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: border),
      ),

      dividerTheme: const DividerThemeData(color: border, thickness: 1),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: mintGreen,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}
