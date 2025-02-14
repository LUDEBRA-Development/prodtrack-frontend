import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:prodtrack/pages/employee/index_employee_page.dart';
import 'package:prodtrack/pages/index_pages.dart';
import 'package:prodtrack/pages/login_page.dart';
import 'package:prodtrack/services/firebase_service.dart';

class AuthController extends GetxController {
  // Instancia de FirebaseService para las operaciones de autenticación.
  final FirebaseService _firebaseService = FirebaseService();

  // Variable observable que indica si está cargando (para mostrar el spinner).
  var isLoading = false.obs;

  // Observa el estado del usuario (sesión iniciada o no).
  var user = Rxn<User>();

  // Instancia de GetStorage para almacenar localmente las credenciales del usuario.
  final storage = GetStorage();

  @override
  void onInit() {
    super.onInit();
    _autoLogin(); // Verificar si el usuario tiene credenciales guardadas para intentar login automático.
  }

  // Método para registrar al usuario con email, contraseña, nombre, apellido, nombre de usuario e identificación.
  Future<void> register(String email, String password, String name,
      String lastName, String id) async {
    try {
      isLoading.value = true; // Indicador de carga activado.

      // Registrar al usuario en Firebase.
      User? newUser = await _firebaseService.registerWithEmail( email, password, name, lastName, id);

      if (newUser != null) {
        // Actualizar el perfil del usuario con el nombre completo (nombre y apellido).
        await newUser.updateDisplayName('$name $lastName');
        await newUser.reload(); // Recargar los datos del usuario.
        user.value = FirebaseAuth.instance.currentUser; // Actualizar el usuario actual.

        // Guardar las credenciales localmente incluyendo todos los datos adicionales.
        await _saveCredentials(email, password, name, lastName, id);
        Get.snackbar("Mensaje", "Se  registro  de forma exitosa");
        Get.offAll(() =>  LoginPage()); // Redirigir a la página de inicio.
      } else {
        Get.snackbar("Error", "No se pudo registrar el usuario");
      }
    } catch (e) {
      Get.snackbar("Error", "Ocurrió un error durante el registro");
    } finally {
      isLoading.value = false; // Apagar el indicador de carga.
    }
  }

  // Método para iniciar sesión con email y contraseña.
Future<void> login(String email, String password) async {
  try {
    isLoading.value = true; 
    User? loggedInUser = await _firebaseService.loginWithEmail(email, password);
    Map<String, dynamic>? userInfo = await _firebaseService.getUserRoleAndStatus();

    if (loggedInUser != null && userInfo != null) {
      user.value = loggedInUser; 
      await _saveCredentials(email, password, "", "", ""); // Guardar las credenciales localmente.

      bool isActive = userInfo['isActive'] ?? false; // Asegúrate de manejar null con un valor por defecto.
      String role = userInfo['rol'] ?? '';

      if (!isActive) {
        Get.snackbar("Error", "El usuario no está activado. Por favor, contacta al administrador.");
        return; // Termina la ejecución si el usuario no está activo.
      }

      if (role == 'admin') {
        Get.offAll(() => const indexPages()); // Redirige a la página de administradores.
      } else if (role == 'employee') {
        Get.offAll(() =>  indexPagesEmployee()); // Redirige a la página de usuarios normales.
      } else {
        Get.snackbar("Error", "El usuario no tiene un rol válido. Por favor, contacta al soporte.");
      }
    } else {
      Get.snackbar("Error", "No se pudo iniciar sesión. Verifica tus credenciales.");
    }
  } catch (e) {
    Get.snackbar("Error", "Ocurrió un error durante el inicio de sesión: $e");
  } finally {
    isLoading.value = false; // Apaga el indicador de carga.
  }
}


  // Método para cerrar sesión.
  Future<void> signOut() async {
    await _firebaseService.signOut(); // Cerrar sesión en Firebase.
    await _clearCredentials(); // Eliminar las credenciales guardadas.
    user.value = null; // Limpiar el estado del usuario.
    Get.snackbar("Sesión cerrada", "Hasta pronto");
    Get.offAll(() => LoginPage()); // Redirigir a la página de login.
  }

  // Guardar credenciales usando GetStorage, incluyendo nuevos datos.
  Future<void> _saveCredentials(String email, String password, String name,
      String lastName, String id) async {
    storage.write('email', email); // Guardar email.
    storage.write('password', password); // Guardar contraseña.
    storage.write('name', name); // Guardar nombre.
    storage.write('lastName', lastName); // Guardar apellido.
    storage.write('id', id); // Guardar identificación.
  }

  // Intentar login automático si hay credenciales guardadas.
  Future<void> _autoLogin() async {
    String? email = storage.read('email'); // Leer email.
    String? password = storage.read('password'); // Leer contraseña.

    if (email != null && password != null) {
      await login(email,
          password); // Intentar iniciar sesión con credenciales guardadas.
    }
  }

  // Eliminar credenciales guardadas.
  Future<void> _clearCredentials() async {
    storage.remove('email');
    storage.remove('password');
    storage.remove('name');
    storage.remove('lastName');
    storage.remove('id');
  }
}
