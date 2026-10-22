// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get petsConsentFullText =>
      'Para darte una orientación más precisa, el asistente puede leer el historial clínico de tu animal. Cuando haces una pregunta, puede leer las tres entradas más recientes, con el título, la categoría (visita, prueba, vacuna, tratamiento o documento), la fecha del evento, la descripción y el texto de los documentos adjuntos, aunque no estén relacionados con la pregunta. También puede leer las enfermedades previas que sigan en curso, con el nombre y la fecha de inicio, como máximo cinco. Si pides que explique una prueba, puede leer los documentos relacionados, como máximo dos. De un documento muy largo solo lee el principio. Lo que lee se envía al proveedor externo de inteligencia artificial que escribe la respuesta. VetApp lo usa solo para responderte. Puedes retirar el consentimiento en cualquier momento desde la ficha del animal o los Ajustes: se aplica a las solicitudes posteriores.';

  @override
  String get appTitle => 'VET APP';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get commonSkip => 'Saltar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonYes => 'Sí';

  @override
  String get commonNo => 'No';

  @override
  String get commonLoading => 'Cargando…';

  @override
  String get commonDone => 'Hecho';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonShare => 'Compartir';

  @override
  String get languagePickerTitle => 'Elige tu idioma';

  @override
  String get languagePickerSubtitle =>
      'Puedes cambiarlo cuando quieras en Ajustes.';

  @override
  String get languageSectionTitle => 'Idioma';

  @override
  String get languageSectionHint =>
      'Al cambiar el idioma también cambian las unidades predeterminadas, si no las has elegido.';

  @override
  String get authBannerCheckFieldsTitle => 'Revisa los campos';

  @override
  String get authLoginFieldsInvalidMessage =>
      'Introduce un correo válido y una contraseña de al menos 6 caracteres.';

  @override
  String get authLoginLoadingTitle => 'Iniciando sesión';

  @override
  String get authLoginLoadingMessage => 'Comprobando tus credenciales.';

  @override
  String get authLoginSuccessTitle => 'Sesión iniciada';

  @override
  String get authLoginSuccessMessage =>
      'Tu sesión está lista. Abriendo la app.';

  @override
  String get authLoginFailureTitle => 'No se pudo iniciar sesión';

  @override
  String get authLoginTitle => 'Qué alegría verte de nuevo.';

  @override
  String get authLoginSubtitle =>
      'Inicia sesión para encontrar tus mascotas, recordatorios y documentos.';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authEmailHint => 'nombre@dominio.es';

  @override
  String get authEmailRequired => 'Introduce tu correo electrónico.';

  @override
  String get authEmailInvalid => 'Correo electrónico no válido.';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authPasswordHint => 'Al menos 6 caracteres';

  @override
  String get authPasswordRequiredLogin => 'Introduce tu contraseña.';

  @override
  String get authPasswordRequiredNew => 'Introduce una contraseña.';

  @override
  String get authPasswordMinLength => 'Mínimo 6 caracteres.';

  @override
  String get authPasswordShow => 'Mostrar contraseña';

  @override
  String get authPasswordHide => 'Ocultar contraseña';

  @override
  String get authRememberMe => 'Mantener la sesión iniciada';

  @override
  String get authForgotPasswordLink => '¿Has olvidado tu contraseña?';

  @override
  String get authLoginButton => 'Iniciar sesión';

  @override
  String get authNoAccountRegisterLink => '¿Aún no tienes cuenta? Regístrate';

  @override
  String get authTermsOfServiceLabel => 'Términos del servicio';

  @override
  String get authPrivacyPolicyLabel => 'Política de privacidad';

  @override
  String authTermsAcceptance(String terms, String privacy) {
    return 'Acepto los $terms y la $privacy';
  }

  @override
  String get authRegisterCheckTitle => 'Una última comprobación';

  @override
  String get authRegisterTermsRequired =>
      'Acepta la política de privacidad y el aviso para continuar.';

  @override
  String get authRegisterFieldsInvalid =>
      'Revisa los campos: el nombre, el correo y la contraseña deben ser válidos.';

  @override
  String get authRegisterLoadingTitle => 'Creando la cuenta';

  @override
  String get authRegisterLoadingMessage =>
      'Creando tu cuenta y preparando tu sesión.';

  @override
  String get authRegisterSuccessTitle => 'Cuenta lista';

  @override
  String get authRegisterSuccessMessage =>
      'Registro completado. Te llevo a la página de inicio.';

  @override
  String get authRegisterFailureTitle => 'No se pudo crear la cuenta';

  @override
  String get authRegisterTitle => 'Crea tu perfil.';

  @override
  String get authRegisterSubtitle =>
      'Solo unos datos para empezar a gestionar la salud y los documentos de tus mascotas.';

  @override
  String get authNameLabel => 'Nombre';

  @override
  String get authNameHint => 'Tu nombre';

  @override
  String get authNameRequired => 'Introduce tu nombre.';

  @override
  String get authConfirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get authConfirmPasswordHint => 'Repite la contraseña';

  @override
  String get authPasswordsMismatch => 'Las contraseñas no coinciden.';

  @override
  String get authRegisterButton => 'Crear cuenta';

  @override
  String get authHaveAccountLoginLink => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authResetInvalidTitle => 'Correo no válido';

  @override
  String get authResetInvalidMessage =>
      'Introduce una dirección de correo válida para continuar.';

  @override
  String get authResetLoadingTitle => 'Enviando';

  @override
  String get authResetLoadingMessage =>
      'Preparando la solicitud de recuperación de contraseña.';

  @override
  String get authResetSuccessTitle => 'Correo enviado';

  @override
  String get authResetSuccessMessage =>
      'Si la cuenta existe, recibirás un enlace para recuperar el acceso.';

  @override
  String get authResetFailureTitle => 'No se pudo enviar';

  @override
  String get authResetTitle => 'Recupera tu acceso.';

  @override
  String get authResetSubtitle =>
      'Introduce tu correo y te enviaremos un enlace para restablecer la contraseña.';

  @override
  String get authResetSendButton => 'Enviar enlace';

  @override
  String get authBackToLoginLink => 'Volver al inicio de sesión';

  @override
  String get authSetPasswordLoadingTitle => 'Actualizando';

  @override
  String get authSetPasswordLoadingMessage => 'Guardando la nueva contraseña.';

  @override
  String get authSetPasswordFailureTitle => 'No se pudo actualizar';

  @override
  String get authSetPasswordTitle => 'Establece una nueva contraseña.';

  @override
  String get authSetPasswordSubtitle =>
      'Elige una nueva contraseña para tu cuenta.';

  @override
  String get authNewPasswordLabel => 'Nueva contraseña';

  @override
  String get authSetPasswordSaveButton => 'Guardar nueva contraseña';

  @override
  String get authLegalShareTooltip => 'Compartir o descargar';

  @override
  String get authLegalLoadError =>
      'No puedo cargar el texto ahora. Inténtalo en unos instantes.';

  @override
  String get authLegalPreparingNotice =>
      'La política de privacidad completa está en preparación y estará disponible aquí pronto, con opción de descarga.';

  @override
  String get authHubTitle => 'VetApp: tus mascotas al alcance de la pata';

  @override
  String get authHubSubtitle =>
      'Inicia sesión o crea una cuenta nueva en pocos segundos.';

  @override
  String get authHubCreateAccount => 'Crear una cuenta';

  @override
  String get authHubPrivacyNote =>
      'Tus datos son privados y solo se usan para gestionar el perfil de tu mascota.';

  @override
  String get authErrorEmailExists =>
      'Ya existe una cuenta con este correo. Intenta iniciar sesión.';

  @override
  String get authErrorWeakPassword =>
      'La contraseña es demasiado débil: usa al menos 6 caracteres, preferiblemente con números o mayúsculas.';

  @override
  String get authErrorEmailInvalid =>
      'La dirección de correo no parece válida.';

  @override
  String get authErrorNoConnection =>
      'Sin conexión. Comprueba la red e inténtalo de nuevo.';

  @override
  String get authErrorLinkExpired =>
      'El enlace ya no es válido o ya se ha usado. Solicita uno nuevo desde la pantalla de recuperación.';

  @override
  String get authErrorRateLimit =>
      'Has solicitado demasiados correos en poco tiempo. Espera unos minutos e inténtalo de nuevo.';

  @override
  String get authErrorInvalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirma primero tu correo: revisa tu bandeja de entrada y abre el enlace que te enviamos.';

  @override
  String get authErrorEmailNotFound => 'No existe una cuenta con este correo.';

  @override
  String get authErrorGeneric =>
      'Algo no ha salido como esperábamos. Inténtalo de nuevo en unos instantes.';

  @override
  String get authNetworkTimeout =>
      'La solicitud tardó demasiado. Inténtalo de nuevo.';

  @override
  String get authNetworkUnexpected => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get consentsErrorLoad =>
      'No pude cargar tus consentimientos. Inténtalo de nuevo.';

  @override
  String get consentsErrorSave =>
      'No pude guardar tu elección. Inténtalo de nuevo.';

  @override
  String get billingErrorStatus =>
      'No pude comprobar tu suscripción. Inténtalo de nuevo.';

  @override
  String get billingErrorSelectPlan =>
      'No pude guardar el plan elegido. Inténtalo de nuevo.';

  @override
  String get billingIncludedPets => 'Perfiles de tus mascotas';

  @override
  String get billingIncludedAssistant =>
      'Un asistente para dudas de salud, comportamiento y rutinas';

  @override
  String get billingIncludedChatMedia =>
      'Fotos, PDF y dictado por voz en el chat';

  @override
  String get billingIncludedReminders => 'Recordatorios';

  @override
  String get billingIncludedNearbyServices =>
      'Servicios cercanos para mascotas';

  @override
  String get billingFreePlaceholder => 'Límites del plan Free: por definir';

  @override
  String get billingPlusPlaceholder =>
      'Funciones adicionales de Plus: por definir';

  @override
  String get billingProPlaceholder =>
      'Funciones adicionales de Pro: por definir';

  @override
  String get billingPlanBadgeRecommended => 'Recomendado';

  @override
  String get billingIncludedInAllPlans => 'Incluido en todos los planes';

  @override
  String get billingPriceFree => 'Gratis';

  @override
  String billingPricePerMonth(String amount) {
    return '$amount/mes';
  }

  @override
  String billingPricePerMonthYearly(String amount) {
    return '$amount/mes, facturado anualmente';
  }

  @override
  String get billingTitle => 'Suscripción y pagos';

  @override
  String billingPlanSwitched(String plan) {
    return 'Ahora tienes el plan $plan.';
  }

  @override
  String get billingPaymentHistory => 'Historial de pagos';

  @override
  String get billingPaymentHistoryComingSoon =>
      'Aquí podrás consultar tus facturas y recibos.';

  @override
  String get billingComparePlans => 'Comparar planes';

  @override
  String get billingPaymentMethodsSection => 'Métodos de pago';

  @override
  String get billingInvoicingSection => 'Facturación';

  @override
  String get billingTrialBannerTitle => 'Prueba gratuita activa';

  @override
  String billingTrialBannerDaysLeft(int days) {
    return 'Te quedan $days días gratis, sin tarjeta. Elige un plan cuando quieras o al terminar la prueba.';
  }

  @override
  String get billingTrialBannerEnding =>
      'Tu prueba gratuita está a punto de terminar: elige un plan para seguir usando VetApp.';

  @override
  String get billingDeveloperBanner =>
      'Cuenta de desarrollador: acceso ilimitado, no se requiere plan.';

  @override
  String get billingCurrentPlanLabel => 'Tu plan';

  @override
  String billingRenewalOn(String date) {
    return 'Renovación el $date';
  }

  @override
  String get billingCycleMonthly => 'Mensual';

  @override
  String get billingCycleYearly => 'Anual';

  @override
  String get billingCurrentPlanButton => 'Plan actual';

  @override
  String get billingBackToFree => 'Volver a Free';

  @override
  String billingSwitchToPlan(String plan) {
    return 'Cambiar a $plan';
  }

  @override
  String billingCardExpires(String expiry) {
    return 'Caduca $expiry';
  }

  @override
  String billingCardExpiresDefault(String expiry) {
    return 'Caduca $expiry · Predeterminada';
  }

  @override
  String get billingSetDefault => 'Establecer como predeterminado';

  @override
  String get billingRemove => 'Eliminar';

  @override
  String get billingAddPaymentMethod => 'Añadir método de pago';

  @override
  String get billingCardBrandLabel => 'Red de tarjeta';

  @override
  String get billingCardLast4Label => 'Últimos 4 dígitos';

  @override
  String get billingCardLast4Error => 'Introduce 4 dígitos';

  @override
  String get billingExpiryMonthLabel => 'Mes';

  @override
  String get billingExpiryYearLabel => 'Año';

  @override
  String get billingPaywallTitle => 'Tu prueba gratuita ha terminado.';

  @override
  String get billingPaywallSubtitle =>
      'Elige cómo continuar con VetApp. Puedes cambiar de plan cuando quieras en Ajustes.';

  @override
  String billingChoosePlan(String plan) {
    return 'Elegir $plan';
  }

  @override
  String billingTrialDialogTitle(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Te quedan $daysLeft días de prueba',
      one: 'Último día de prueba',
    );
    return '$_temp0';
  }

  @override
  String get billingTrialDialogBody =>
      'Algunas funciones están limitadas en el plan Free. Cambia a Plus o Pro para tener acceso ilimitado cuando termine la prueba.';

  @override
  String get billingTrialDialogLater => 'Más tarde';

  @override
  String get billingTrialDialogSeePlans => 'Ver planes';

  @override
  String get firstRunWelcomeTitle => 'Te damos la bienvenida a VetApp.';

  @override
  String get firstRunPlanIntroSubtitle =>
      'Elige cómo empezar: prueba todo gratis durante 10 días sin tarjeta o elige un plan ahora.';

  @override
  String get firstRunPlanOrChoose => 'O ELIGE UN PLAN AHORA';

  @override
  String get firstRunTrialCardTitle => 'Prueba gratuita — 10 días';

  @override
  String get firstRunTrialCardBody =>
      'No se requiere tarjeta. Al finalizar los 10 días, te pediremos que elijas un plan para continuar.';

  @override
  String get firstRunTrialStartButton => 'Iniciar prueba gratuita';

  @override
  String get firstRunPlanSelectButton => 'Elegir';

  @override
  String get firstRunAddPetTitle => 'Añade tu primer animal';

  @override
  String get firstRunAddPetBody =>
      'Solo necesitas un par de minutos: nombre, especie y algunos detalles. También puedes hacerlo más tarde desde Animales.';

  @override
  String get firstRunAddPetNow => 'Añadir ahora';

  @override
  String get firstRunAddPetLater => 'Saltar por ahora';

  @override
  String get firstRunNotificationsTitle => 'No te pierdas los recordatorios';

  @override
  String get firstRunNotificationsBody =>
      'Activa las notificaciones para recibir avisos sobre vacunas, medicamentos y próximas visitas. Puedes cambiarlo cuando quieras en Ajustes.';

  @override
  String get firstRunNotificationsEnable => 'Activar notificaciones';

  @override
  String get firstRunNotificationsLater => 'Ahora no';

  @override
  String get firstRunTutorialPetsTitle => 'Un perfil para cada animal';

  @override
  String get firstRunTutorialPetsBody =>
      'Especie y raza, peso, notas médicas y documentos: todo organizado para cada mascota y siempre a mano.';

  @override
  String get firstRunTutorialAssistantTitle => 'Pregunta a tu asistente';

  @override
  String get firstRunTutorialAssistantBody =>
      'Haz preguntas sobre la salud de tus animales y recibe respuestas adaptadas a su situación.';

  @override
  String get firstRunTutorialRemindersTitle => 'No olvides ninguna fecha';

  @override
  String get firstRunTutorialRemindersBody =>
      'Vacunas, medicamentos y visitas: crea un recordatorio y VetApp te avisará en el momento adecuado.';

  @override
  String get firstRunTutorialStart => 'Empezar';

  @override
  String get chatLoadingTitle => 'Abriendo la conversación';

  @override
  String get chatLoadingSubtitle =>
      'Cargando el hilo y el último contexto disponible.';

  @override
  String get chatEmptyTitle => 'La conversación está vacía';

  @override
  String get chatEmptySubtitle =>
      'Escribe tu primer mensaje para hablar con el asistente.';

  @override
  String get chatEmptyAction => 'Escribir ahora';

  @override
  String chatEmptyGreeting(String pet) {
    return 'Hola, tengo una pregunta sobre $pet.';
  }

  @override
  String get chatErrorTitle => 'Conversación no disponible';

  @override
  String get chatErrorSubtitle => 'Algo salió mal al recuperar el hilo.';

  @override
  String get chatErrorAction => 'Volver a los chats';

  @override
  String get chatMessageEditAction => 'Editar mensaje';

  @override
  String get chatMessageEditHint =>
      'La respuesta y los mensajes posteriores se sustituirán.';

  @override
  String chatComposerHint(String pet) {
    return 'Escribe una pregunta sobre $pet';
  }

  @override
  String chatNewConversationOnPet(String pet) {
    return 'Nueva conversación sobre $pet';
  }

  @override
  String get chatNewConversationPrompt =>
      'Escribe abajo lo que estás observando y te responderé enseguida.';

  @override
  String get chatTypingText => 'Escribiendo una respuesta…';

  @override
  String get chatTypingSlowText =>
      'Está tardando más de lo habitual. La respuesta llegará pronto...';

  @override
  String chatDefaultTitle(String pet) {
    return 'Chat con $pet';
  }

  @override
  String get chatListeningText => 'Escuchando… toca para detener';

  @override
  String get chatTranscribingText => 'Transcribiendo…';

  @override
  String get chatEditingLabel => 'Edición del mensaje';

  @override
  String get chatListeningHint => 'Escuchando…';

  @override
  String get chatTranscribingHint => 'Transcribiendo el mensaje…';

  @override
  String get chatAddPhotoTooltip => 'Añadir una foto';

  @override
  String get chatStopRecordingTooltip => 'Detener y transcribir';

  @override
  String get chatVoiceMessageTooltip => 'Mensaje de voz';

  @override
  String get chatMicPermissionNeeded =>
      'Se necesita permiso para usar el micrófono.';

  @override
  String get chatMicStartFailed =>
      'No puedo iniciar el micrófono. Inténtalo de nuevo.';

  @override
  String get chatRecordingFailed => 'La grabación falló. Inténtalo de nuevo.';

  @override
  String get chatRecordingReadFailed =>
      'No se pudo leer la grabación. Inténtalo de nuevo.';

  @override
  String get chatPhotoAnalyzing => 'Analizando la foto…';

  @override
  String get chatPhotoReady => 'Foto lista para enviar';

  @override
  String get chatRemovePhotoTooltip => 'Quitar foto';

  @override
  String chatRecordingSemantics(String listening, int minutes, String seconds) {
    return '$listening, $minutes minutos y $seconds segundos';
  }

  @override
  String get chatCancelEditTooltip => 'Cancelar edición';

  @override
  String get chatMenuTooltip => 'Opciones del chat';

  @override
  String get chatMenuRename => 'Renombrar';

  @override
  String get chatMenuExport => 'Exportar chat';

  @override
  String get chatMenuSummary => 'Resumen';

  @override
  String get chatExportOpenFirst => 'Abre el chat para exportarlo.';

  @override
  String get chatSenderYou => 'Tú';

  @override
  String get chatSenderAssistant => 'Asistente';

  @override
  String get chatRenameTitle => 'Renombrar chat';

  @override
  String get chatRenameFieldLabel => 'Título';

  @override
  String get chatSummaryLoading => 'Preparando el resumen…';

  @override
  String get chatSummaryTitle => 'Resumen para el veterinario';

  @override
  String get chatSummaryDisclaimer =>
      'Este resumen se genera automáticamente y no es un diagnóstico. Consulta al veterinario para decisiones clínicas.';

  @override
  String get chatSummaryEmpty => 'No hay resumen disponible.';

  @override
  String get chatDeleteTitle => '¿Eliminar este chat?';

  @override
  String get chatDeleteBody => 'La conversación y sus mensajes se eliminarán.';

  @override
  String get chatFallbackPetName => 'tu mascota';

  @override
  String get chatNewConversation => 'Nueva conversación';

  @override
  String chatNewConversationTitle(String pet) {
    return '$pet - nueva conversación';
  }

  @override
  String chatSavedConversationTitle(String pet) {
    return '$pet - conversación';
  }

  @override
  String chatRetitled(String subject) {
    return 'Chat - $subject';
  }

  @override
  String get chatStatusSaved => 'Conversación guardada';

  @override
  String get chatStatusSent => 'Mensaje enviado';

  @override
  String get chatStatusEdited => 'Mensaje editado';

  @override
  String get chatStatusReplyReady => 'Respuesta lista';

  @override
  String get chatTimeYesterday => 'ayer';

  @override
  String get chatTimeNow => 'ahora';

  @override
  String get chatSummaryNotYet =>
      'El resumen estará disponible después del primer mensaje.';

  @override
  String get chatEditMessageMissing =>
      'Este mensaje ya no está en la conversación.';

  @override
  String get chatEmptyThreadPreview => 'Nuevo hilo listo para usar.';

  @override
  String chatDemoReplyAppetite(String pet) {
    return 'Para $pet, vigilaría el apetito, el agua y la energía durante las próximas 24 horas. Si empeora, contacta al veterinario.';
  }

  @override
  String get chatDemoReplyVomiting =>
      'Si hay vómitos o diarrea, vigila la hidratación y contacta al veterinario si los síntomas se repiten o empeoran.';

  @override
  String chatDemoReplyVaccine(String pet) {
    return 'Puedo ayudarte a programar el refuerzo de $pet y añadir un recordatorio en Inicio.';
  }

  @override
  String chatDemoReplyWeight(String pet) {
    return 'Podemos programar controles de peso de $pet y compararlos con la última visita para ver si cambia la tendencia.';
  }

  @override
  String chatDemoReplyDefault(String pet) {
    return 'Anotado: prepararé un resumen breve de $pet para que tengas un plan práctico y claro.';
  }

  @override
  String get chatErrorContactAssistant =>
      'No pude contactar al asistente. Inténtalo de nuevo.';

  @override
  String get chatErrorAssistantTimeout =>
      'El asistente no respondió a tiempo. Toca Reintentar: si la respuesta ya está lista, la recuperaré.';

  @override
  String get chatErrorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get chatErrorRequestTimeout =>
      'La solicitud caducó. Inténtalo de nuevo.';

  @override
  String get chatErrorEditFailed =>
      'No pude editar el mensaje. Inténtalo de nuevo.';

  @override
  String get chatErrorEditNetwork =>
      'No pude editar el mensaje. Comprueba la conexión.';

  @override
  String chatErrorMessageTooLong(int max) {
    return 'El mensaje es demasiado largo: puedes escribir como máximo $max caracteres. Acórtalo y envíalo de nuevo.';
  }

  @override
  String chatInputLimitReached(int max) {
    return 'Has alcanzado el límite de $max caracteres.';
  }

  @override
  String get chatErrorPetBootstrap =>
      'No pude preparar el perfil de la mascota.';

  @override
  String get chatErrorTitleEmpty => 'El título no puede estar vacío.';

  @override
  String get chatErrorRenameFailed =>
      'No pude renombrar el chat. Inténtalo de nuevo.';

  @override
  String get chatErrorRenameNetwork =>
      'No pude renombrar el chat. Comprueba la conexión.';

  @override
  String get chatErrorSummaryEmpty =>
      'Escribe al menos un mensaje para obtener un resumen.';

  @override
  String get chatErrorSummaryModel =>
      'El modelo no respondió. Inténtalo en unos instantes.';

  @override
  String get chatErrorSummaryFailed =>
      'No pude preparar el resumen. Inténtalo de nuevo.';

  @override
  String get chatErrorSummaryNetwork =>
      'No pude preparar el resumen. Comprueba la conexión.';

  @override
  String get chatErrorDeleteFailed => 'No pude eliminar el chat del servidor.';

  @override
  String get chatErrorListChats => 'No pude cargar tus chats.';

  @override
  String get chatErrorListPets => 'No pude cargar tus mascotas.';

  @override
  String chatErrorConversationLimit(String max) {
    return 'Has alcanzado el máximo de conversaciones ($max) para esta mascota. Cierra una para crear otra.';
  }

  @override
  String get chatErrorConversationNotFound => 'Esta conversación ya no existe.';

  @override
  String get chatErrorAttachmentOffline =>
      'Estás sin conexión o la conexión es inestable. Inténtalo cuando vuelvas a estar en línea.';

  @override
  String get chatErrorAttachmentDownload => 'No pude descargar el archivo.';

  @override
  String get chatErrorAttachmentTooLarge =>
      'El archivo es demasiado grande (máximo 4 MB).';

  @override
  String get chatErrorAttachmentUnsupported =>
      'Este tipo de archivo no es compatible. Puedes subir fotos (JPG, PNG, WEBP) o PDF.';

  @override
  String get chatErrorPdfTooManyPages =>
      'El PDF supera el límite de 30 páginas.';

  @override
  String get chatErrorPdfUnreadable =>
      'No puedo leer este PDF: puede estar dañado o protegido con contraseña.';

  @override
  String get chatErrorAttachmentUpload =>
      'No pude subir el archivo. Inténtalo de nuevo.';

  @override
  String get chatErrorTranscribe => 'No pude transcribir el mensaje de voz.';

  @override
  String get chatSeedConv1Title => 'Moka - apetito y control';

  @override
  String get chatSeedConv1Subtitle =>
      'Ligera pérdida de apetito, seguimiento y plan de acción.';

  @override
  String get chatSeedConv1Preview =>
      'Si sigue activo, podemos observar hasta mañana, anotando el apetito y el agua.';

  @override
  String get chatSeedConv1Status => 'Contexto activo de la mascota';

  @override
  String get chatSeedConv1Msg1 =>
      'Cuéntame qué observas: apetito, energía, agua y heces ayudan a saber si hace falta una visita o basta con vigilar.';

  @override
  String get chatSeedConv1Msg2 =>
      'Desde ayer come menos pero sigue activo. ¿Debo preocuparme ya?';

  @override
  String get chatSeedConv1Msg3 =>
      'Sin vómitos, apatía ni dolor evidente, suele ser útil vigilar durante 24 horas y anotar apetito, agua y heces. Si empeora, contacta al veterinario.';

  @override
  String get chatSeedConv1Msg4 =>
      'Un plan breve: comidas pequeñas, agua siempre disponible y comprobar la temperatura si parece más decaído de lo habitual.';

  @override
  String get chatSeedConv2Title => 'Moka - recordatorio de vacuna';

  @override
  String get chatSeedConv2Subtitle =>
      'Refuerzo anual con nota sobre el antiparasitario.';

  @override
  String get chatSeedConv2Preview =>
      'He programado el refuerzo y un recordatorio de seguimiento para la próxima semana.';

  @override
  String get chatSeedConv2Status => 'Recordatorio activo';

  @override
  String get chatSeedConv2Msg1 =>
      'He programado el refuerzo y añadido una nota sobre el antiparasitario. También podemos coordinar la próxima revisión.';

  @override
  String get chatSeedConv2Msg2 =>
      'Perfecto, ¿puedes avisarme también una semana antes?';

  @override
  String get chatSeedConv2Msg3 =>
      'Claro. Prepararé también una nota visual con el vencimiento más cercano para que lo veas en Inicio.';

  @override
  String get chatSeedConv3Title => 'Moka - informe de visita';

  @override
  String get chatSeedConv3Subtitle =>
      'Resumen del control, tratamiento leve y próxima acción.';

  @override
  String get chatSeedConv3Preview =>
      'Puedo resumir el informe en tres puntos: estado, tratamiento y próxima revisión.';

  @override
  String get chatSeedConv3Status => 'Informe subido';

  @override
  String get chatSeedConv3Msg1 =>
      'Puedo resumir el informe en tres puntos: estado clínico, tratamiento y próximos controles. También puedo preparar una versión breve para compartir.';

  @override
  String get chatSeedConv3Msg2 => 'Sí, dame la versión breve.';

  @override
  String get chatSeedConv3Msg3 =>
      'En breve: estado estable, tratamiento leve durante unos días y seguimiento ya programado.';

  @override
  String get chatSeedAgo2Min => 'hace 2 min';

  @override
  String get chatSeedAgo3Days => 'hace 3 días';

  @override
  String get marketplacePermissionDenied =>
      'Solo quien publicó el anuncio puede editarlo o eliminarlo.';

  @override
  String get marketplaceCategoryKennelsCarriers =>
      'Camas, casetas y transportines';

  @override
  String get marketplaceCategoryLeashesCollars => 'Correas, collares y arneses';

  @override
  String get marketplaceCategoryToys => 'Juguetes';

  @override
  String get marketplaceCategoryClothing => 'Ropa';

  @override
  String get marketplaceCategoryFeeding => 'Cuencos y alimentación';

  @override
  String get marketplaceCategoryHygieneGrooming => 'Higiene y peluquería';

  @override
  String get marketplaceCategoryAquariumsTerrariums => 'Acuarios y terrarios';

  @override
  String get marketplaceCategoryCagesAviaries => 'Jaulas y aviarios';

  @override
  String get marketplaceOther => 'Otro';

  @override
  String get marketplaceConditionNew => 'Nuevo';

  @override
  String get marketplaceConditionLikeNew => 'Como nuevo';

  @override
  String get marketplaceConditionGood => 'Bueno';

  @override
  String get marketplaceConditionWorn => 'Usado';

  @override
  String get marketplaceSpeciesAll => 'Todas las especies';

  @override
  String get marketplaceSpeciesDog => 'Perro';

  @override
  String get marketplaceSpeciesCat => 'Gato';

  @override
  String get marketplaceSpeciesSmallMammal => 'Pequeños mamíferos';

  @override
  String get marketplaceSpeciesBird => 'Ave';

  @override
  String get marketplaceSpeciesReptileAmphibian => 'Reptiles y anfibios';

  @override
  String get marketplaceSpeciesFish => 'Pez';

  @override
  String get marketplacePriceGift => 'En regalo';

  @override
  String get marketplaceDistanceAnywhere => 'Cualquier lugar';

  @override
  String get marketplaceDemoBedTitle => 'Cama acolchada (demo)';

  @override
  String get marketplaceDemoBedDescription => 'Poco usada, tamaño mediano.';

  @override
  String get marketplaceDemoBedArea => 'Centro, Milán';

  @override
  String get marketplaceDemoScratcherTitle => 'Rascador de dos niveles (demo)';

  @override
  String get marketplaceDemoScratcherArea => 'Città Studi, Milán';

  @override
  String get marketplacePageTitle => 'Mercadillo de segunda mano';

  @override
  String get marketplaceMapAction => 'Mapa';

  @override
  String get marketplaceNewListing => 'Nuevo anuncio';

  @override
  String get marketplaceIntro =>
      'Compra, vende y regala artículos para mascotas con otros propietarios.';

  @override
  String get marketplaceDistanceNeedsLocation =>
      'Para filtrar por distancia, indica tu ubicación en Ajustes → Ubicación.';

  @override
  String get marketplaceEmptyFiltered =>
      'Todavía no hay anuncios con estos filtros.';

  @override
  String get marketplaceLoadError =>
      'No puedo cargar los anuncios. Comprueba la conexión.';

  @override
  String get marketplaceFilterAllCategories => 'Todos';

  @override
  String get marketplaceFilterAllSpecies => 'Todas las mascotas';

  @override
  String get marketplaceReportListing => 'Denunciar anuncio';

  @override
  String get marketplaceReasonSpam => 'Spam';

  @override
  String get marketplaceReasonScam => 'Estafa';

  @override
  String get marketplaceReasonProhibitedItem => 'Artículo no permitido';

  @override
  String get marketplaceReasonInappropriate => 'Contenido inapropiado';

  @override
  String get marketplaceReportRemoved =>
      'Gracias, el anuncio se ha eliminado tras los informes recibidos.';

  @override
  String get marketplaceReportSent => 'Informe enviado, gracias.';

  @override
  String get marketplaceDeleteConfirmTitle => '¿Eliminar el anuncio?';

  @override
  String marketplaceDeleteConfirmBody(String title) {
    return '\"$title\" y sus fotos se eliminarán. No se puede deshacer.';
  }

  @override
  String get marketplaceDeleteFailed =>
      'No pude eliminar el anuncio. Inténtalo de nuevo.';

  @override
  String get marketplaceDeleted => 'Anuncio eliminado.';

  @override
  String marketplaceDetailApproxZone(String city) {
    return '$city · zona aproximada';
  }

  @override
  String marketplaceDetailForSpecies(String species) {
    return 'Para: $species';
  }

  @override
  String get marketplaceEditListing => 'Editar anuncio';

  @override
  String get marketplaceDeleting => 'Eliminando...';

  @override
  String get marketplaceDeleteListing => 'Eliminar anuncio';

  @override
  String get marketplaceReporting => 'Enviando informe…';

  @override
  String get marketplaceMapTitle => 'Mapa del mercadillo';

  @override
  String marketplaceListingsCount(int count) {
    return '$count anuncios';
  }

  @override
  String marketplaceMapClusterTitle(int count) {
    return '$count anuncios en esta zona';
  }

  @override
  String get marketplaceMapEmpty => 'No hay anuncios con estos filtros.';

  @override
  String marketplaceMapSummary(int count) {
    return '$count anuncios · posiciones aproximadas (alrededor de 1 km)';
  }

  @override
  String get marketplaceLocationErrorWithHome =>
      'No puedo detectar tu ubicación. Comprueba los permisos o usa tu residencia.';

  @override
  String get marketplaceLocationErrorNoHome =>
      'No puedo detectar tu ubicación. Es necesaria para mostrar el anuncio en la zona aproximada correcta. Comprueba los permisos e inténtalo de nuevo.';

  @override
  String get marketplaceCameraOpenError => 'No puedo abrir la cámara.';

  @override
  String get marketplaceGalleryOpenError => 'No puedo abrir la galería.';

  @override
  String marketplacePhotosSkipped(int count) {
    return 'Se omitieron $count fotos ilegibles.';
  }

  @override
  String marketplacePhotosMaxReached(int max) {
    return 'Puedes añadir como máximo $max fotos.';
  }

  @override
  String get marketplaceZoneWait =>
      'Espera a que se encuentre la zona e inténtalo de nuevo.';

  @override
  String get marketplaceSaveFailed =>
      'No pude guardar el anuncio. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get marketplacePriceRequired =>
      'Introduce un precio o elige \"En regalo\"';

  @override
  String get marketplacePriceInvalid => 'Introduce un precio válido';

  @override
  String get marketplacePriceNegative => 'El precio no puede ser negativo';

  @override
  String get marketplacePriceZero => 'Para regalarlo, elige \"En regalo\"';

  @override
  String get marketplacePriceTooHigh => 'Precio demasiado alto';

  @override
  String get marketplaceFieldTitle => 'Título';

  @override
  String get marketplaceTitleRequired => 'Introduce un título';

  @override
  String get marketplaceFieldDescription => 'Descripción (opcional)';

  @override
  String get marketplaceFieldCategory => 'Categoría';

  @override
  String get marketplaceCategoryRequired => 'Elige una categoría';

  @override
  String get marketplaceConditionLabel => 'Estado';

  @override
  String get marketplaceSpeciesLabel => 'Para qué mascotas';

  @override
  String get marketplaceSpeciesRequired =>
      'Indica para qué mascotas es, o elige \"Todas las especies\"';

  @override
  String get marketplaceGiftSubtitle => 'Regálalo a quien lo necesite';

  @override
  String get marketplaceFieldPrice => 'Precio en €';

  @override
  String get marketplaceSaving => 'Guardando…';

  @override
  String get marketplaceSaveChanges => 'Guardar cambios';

  @override
  String get marketplacePublish => 'Publicar anuncio';

  @override
  String marketplacePhotosTitle(int count, int max) {
    return 'Fotos ($count/$max)';
  }

  @override
  String get marketplaceTakePhoto => 'Hacer foto';

  @override
  String get marketplaceFromGallery => 'Desde la galería';

  @override
  String get marketplacePhotosPrivacy =>
      'Antes de subirlas, eliminamos los datos ocultos de las fotos (ubicación, dispositivo y fecha).';

  @override
  String get marketplaceLocationTitle => 'Ubicación';

  @override
  String get marketplaceLocationKeep => 'Zona actual del anuncio';

  @override
  String get marketplaceLocationNow => 'Donde estoy ahora';

  @override
  String get marketplaceLocationHome => 'Residencia';

  @override
  String get marketplaceLocationHomeHint =>
      'Para usar tu residencia, indícala en Ajustes → Ubicación.';

  @override
  String get marketplaceLocationSearching => 'Buscando tu zona...';

  @override
  String get marketplaceZoneLabel => 'Zona mostrada (barrio o municipio)';

  @override
  String get marketplaceZoneHelper => 'Sin calle ni número';

  @override
  String get marketplacePrivacyApproxOnMap =>
      'El anuncio aparece en el mapa en un punto aproximado (alrededor de 1 km), nunca en tu dirección.';

  @override
  String get marketplacePrivacyApproxAlways =>
      'Por tu privacidad, la ubicación del anuncio siempre es aproximada (alrededor de 1 km), nunca tu dirección exacta.';

  @override
  String get medicalActionOpen => 'Abrir';

  @override
  String get medicalActionSend => 'Enviar';

  @override
  String get medicalActionRename => 'Renombrar';

  @override
  String get medicalFileUnavailable =>
      'El archivo no está disponible ahora. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get medicalPdfOpenFailed =>
      'No pude abrir el PDF. Inténtalo de nuevo o usa Enviar.';

  @override
  String get medicalNoPdfAppTitle =>
      'No hay ninguna aplicación para abrir el PDF';

  @override
  String get medicalNoPdfAppBody =>
      'Este dispositivo no tiene una app para abrir PDF. Puedes enviar el archivo a una app que lo abra.';

  @override
  String get medicalPreparingFiles => 'Preparando archivos para enviar…';

  @override
  String get medicalNoFilesToSend =>
      'No hay archivos disponibles para enviar. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String medicalFilesMissing(int count) {
    return 'No se incluyeron $count archivos no disponibles.';
  }

  @override
  String get medicalDeleteConfirmTitle => '¿Eliminar este documento?';

  @override
  String medicalDeleteConfirmBody(String title) {
    return '\"$title\" se eliminará definitivamente.';
  }

  @override
  String get medicalDeleting => 'Eliminando el informe…';

  @override
  String get medicalRenameTitle => 'Renombrar informe';

  @override
  String get medicalRenameFieldLabel => 'Nombre del archivo';

  @override
  String get medicalDefaultRecordTitle => 'Informe clínico';

  @override
  String get medicalSaveNoSession =>
      'Acceso no disponible: vuelve a iniciar sesión e inténtalo de nuevo.';

  @override
  String medicalSavePetNotSynced(String petName) {
    return 'El perfil de $petName no está sincronizado con el servidor. Resuélvelo antes de subir informes.';
  }

  @override
  String get medicalSaveFailed =>
      'No pude guardar el informe en el servidor. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get medicalRenameFailed =>
      'No pude renombrar el informe. Inténtalo de nuevo.';

  @override
  String get medicalDeleteFailed =>
      'No pude eliminar el informe. Inténtalo de nuevo.';

  @override
  String get medicalRecordMetaNotUploaded => 'Archivo no subido al servidor';

  @override
  String get medicalRecordMetaAnalysisFailed =>
      'Archivo guardado, lectura automática fallida';

  @override
  String get medicalRecordMetaUploadedNow => 'Subido por ti ahora';

  @override
  String get medicalRecordBadgeNotUploaded => 'No subido';

  @override
  String get medicalRecordBadgeNew => 'Nuevo';

  @override
  String get medicalRecordSourceLocalOnly => 'Solo en este teléfono';

  @override
  String get medicalRecordSourceUploadedByYou => 'Subido por ti';

  @override
  String get medicalTimelineImported => 'Importado';

  @override
  String get medicalTimelineUpload => 'Carga';

  @override
  String get medicalTimelineFailed => 'Fallido';

  @override
  String get medicalTimelineCompleted => 'Completado';

  @override
  String get medicalTimelineReadyToSend => 'Listo para enviar';

  @override
  String get medicalTimelineAvailable => 'Disponible';

  @override
  String get medicalUploadTitle => 'Subir documento';

  @override
  String medicalUploadForPet(String petName) {
    return 'Para $petName · PDF, JPG o PNG';
  }

  @override
  String get medicalUploadAction => 'Subir';

  @override
  String get medicalUploadPickPrompt => 'Toca para elegir un archivo';

  @override
  String get medicalUploadPickHint => 'PDF, JPG o PNG desde tu dispositivo';

  @override
  String get medicalUploadChange => 'Cambiar';

  @override
  String get medicalUploadFailedTitle => 'El archivo no se ha subido';

  @override
  String medicalUploadFailedBody(String reason) {
    return '$reason También puedes guardarlo solo en este teléfono: se marcará como «No subido» y no estará disponible en otros dispositivos.';
  }

  @override
  String get medicalUploadFailedDefaultReason =>
      'Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get medicalUploadSaveLocalOnly => 'Guardar solo en el teléfono';

  @override
  String get medicalUploadDemoSubtitle =>
      'Sube un PDF, JPG o PNG y completa los metadatos.';

  @override
  String get medicalUploadDemoAction => 'Detalle';

  @override
  String get medicalUploadDemoCardBody =>
      'Subido correctamente y listo para revisar los metadatos.';

  @override
  String get medicalListTitle => 'Informes';

  @override
  String get medicalListSubtitle =>
      'Informes, notas y adjuntos de Moka en un archivo claro.';

  @override
  String get medicalListSyncTitle => 'Sincronización de informes';

  @override
  String get medicalListSyncBody =>
      'Recuperando documentos y metadatos de Supabase o de la fuente de demostración.';

  @override
  String get medicalListLoadErrorTitle => 'No se pudo cargar el archivo';

  @override
  String get medicalListLoadErrorBody =>
      'Comprueba la conexión y reintenta, o continúa con la demostración.';

  @override
  String get medicalListEmptyTitle => 'Aún no hay documentos';

  @override
  String get medicalListEmptyBody =>
      'Sube el primer informe para empezar tu archivo documental.';

  @override
  String get medicalListUploadFirst => 'Subir el primer archivo';

  @override
  String medicalListSummaryAllTitle(int count) {
    return '$count documentos activos';
  }

  @override
  String medicalListSummaryPetTitle(int count, String petName) {
    return '$count documentos de $petName';
  }

  @override
  String get medicalListSummaryAllBody =>
      '1 informe listo para compartir, 1 prueba para revisar y 1 nota archivada.';

  @override
  String medicalListSummaryPetBody(String petName) {
    return 'Filtros activos en el perfil de $petName. Abre los documentos útiles sin distracciones.';
  }

  @override
  String get medicalListNextActionTitle => 'Próxima acción';

  @override
  String get medicalListNextActionAllBody =>
      'Abre el informe de vacunación de Moka y compártelo con Francesco.';

  @override
  String medicalListNextActionPetBody(String petName) {
    return 'Comparte el último documento de $petName y conserva la nota en su perfil.';
  }

  @override
  String medicalListEmptyPetTitle(String petName) {
    return 'No hay documentos para $petName';
  }

  @override
  String get medicalListEmptyPetBody =>
      'Cambia el filtro o sube un documento nuevo para esta mascota.';

  @override
  String get medicalListRemoveFilter => 'Quitar filtro';

  @override
  String medicalFilterAll(int count) {
    return 'Todos ($count)';
  }

  @override
  String get medicalMetaType => 'Tipo';

  @override
  String get medicalMetaDate => 'Fecha';

  @override
  String get medicalMetaSource => 'Fuente';

  @override
  String get medicalMetaFormat => 'Formato';

  @override
  String get medicalStatePreviewPill => 'Estado de vista previa';

  @override
  String get medicalStateLoadingPill => 'Carga';

  @override
  String get medicalChecklistFormat => 'Formato de archivo compatible';

  @override
  String get medicalChecklistMetadata => 'Metadatos extraídos';

  @override
  String get medicalChecklistLinkedPet => 'Vinculado a la mascota activa';

  @override
  String get homeGreeting => 'Buenos días';

  @override
  String get homeAgendaTitle => 'Próximas actividades';

  @override
  String get homeAgendaLoadingSubtitle =>
      'Actividades puntuales y recurrentes para todos los animales.';

  @override
  String homeAgendaSummary(int count) {
    return '$count actividades en los próximos 10 días';
  }

  @override
  String get homeNewsTitle => 'Curiosidades para tus animales';

  @override
  String get homeNewsSubtitle =>
      'Noticias del mundo de las mascotas seleccionadas para ti.';

  @override
  String get homeNewsUnavailable =>
      'Las noticias no están disponibles ahora. Inténtalo más tarde.';

  @override
  String get homeNewsMore => 'Descubrir más noticias';

  @override
  String get homeNearbyTitle => 'Cerca de mí';

  @override
  String get homeSponsorBanner =>
      'Espacio reservado para nuestros colaboradores.';

  @override
  String get homeSectionLoading => 'Cargando…';

  @override
  String get shellTabHome => 'Inicio';

  @override
  String get shellTabPets => 'Animales';

  @override
  String get shellTabActivities => 'Actividades';

  @override
  String get shellTabSettings => 'Ajustes';

  @override
  String get shellRailFooter => 'Un espacio clínico acogedor';

  @override
  String get shellInterruptedWalkTitle => 'Paseo interrumpido';

  @override
  String shellInterruptedWalkBody(String distance) {
    return 'Ha quedado un paseo en curso ($distance hasta ahora). ¿Quieres reanudarlo?';
  }

  @override
  String get shellInterruptedWalkDiscard => 'Descartar';

  @override
  String get shellInterruptedWalkResume => 'Reanudar';

  @override
  String shellWalkPausedBanner(String distance) {
    return 'Paseo en pausa · $distance';
  }

  @override
  String shellWalkActiveBanner(String elapsed, String distance) {
    return 'Paseo en curso · $elapsed · $distance';
  }

  @override
  String get splashMessageWalks => '¡Registra los paseos con tu perro!';

  @override
  String get splashMessageVet =>
      'Consulta al veterinario virtual, las 24 horas';

  @override
  String get splashMessageReminders =>
      'No olvides un vencimiento: recordatorios y calendario';

  @override
  String get splashMessageRecords => 'Ten los informes siempre a mano';

  @override
  String get splashMessageNearby =>
      'Descubre actividades cercanas para mascotas';

  @override
  String get splashMessageNews => 'Sigue las novedades del mundo animal';

  @override
  String get splashMessageProfiles =>
      '¡Un perfil para cada amigo de cuatro patas (o con aletas)!';

  @override
  String get splashMessageHealthBook =>
      'El historial sanitario en el bolsillo, sin papeles sueltos';

  @override
  String get splashMessageVaccines =>
      'Vacunas, desparasitación y visitas: te las recordamos';

  @override
  String get splashMessageSpecies =>
      'Perro, gato, conejo, loro o pez: aquí hay sitio para todos';

  @override
  String get sharedGuestName => 'Invitado';

  @override
  String get sharedComingSoon => 'Próximamente';

  @override
  String get sharedLoadingLabel => 'Carga';

  @override
  String get sharedAttachmentTooLarge =>
      'El archivo es demasiado grande (máximo 4 MB).';

  @override
  String get sharedAttachmentInvalidPdf =>
      'Este archivo no parece un PDF válido.';

  @override
  String get sharedAiGenerated => 'Generado por IA';

  @override
  String get sharedAiNotReviewed => 'Respuesta automática, no revisada';

  @override
  String get petsAgeLessThanMonth => 'Menos de un mes';

  @override
  String petsAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: '1 mes',
    );
    return '$_temp0';
  }

  @override
  String petsAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count años',
      one: '1 año',
    );
    return '$_temp0';
  }

  @override
  String petsProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfiles',
      one: '1 perfil',
    );
    return '$_temp0';
  }

  @override
  String petsSpeciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count especies',
      one: '1 especie',
    );
    return '$_temp0';
  }

  @override
  String petsFishCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peces',
      one: '1 pez',
    );
    return '$_temp0';
  }

  @override
  String petsAquariumSummary(String species, String fish) {
    return '$species · $fish';
  }

  @override
  String get petsBreedUnspecified => 'Raza no especificada';

  @override
  String get petsSpeciesUnspecified => 'Especie no especificada';

  @override
  String petsBreedOtherWithSize(String size) {
    return 'Otros · Tamaño $size';
  }

  @override
  String get petsHabitatAquarium => 'Acuario';

  @override
  String get petsHabitatTerrarium => 'Terrario';

  @override
  String get petsHabitatAviary => 'Aviario';

  @override
  String get petsHabitatGeneric => 'Hábitat';

  @override
  String get petsCreateTitle => 'Crear un perfil de mascota';

  @override
  String get petsCreateLoading => 'Preparando el formulario de creación…';

  @override
  String get petsCreateErrorTitle => 'Formulario de creación no disponible';

  @override
  String get petsCreateErrorDefault =>
      'Ahora mismo no se puede crear un nuevo perfil de mascota.';

  @override
  String get petsCreateFormTitle => 'Nuevo perfil';

  @override
  String get petsCreateSubmit => 'Guardar perfil';

  @override
  String get petsCreateUnsyncedSnack =>
      'El perfil se ha guardado en el teléfono, pero no en el servidor. Ábrelo desde la lista y toca Reintentar.';

  @override
  String petsEditTitle(String name) {
    return 'Editar $name';
  }

  @override
  String get petsEditLoading => 'Cargando el formulario de edición…';

  @override
  String get petsEditErrorTitle => 'Edición no disponible';

  @override
  String get petsEditErrorDefault =>
      'No se puede abrir este perfil para editarlo.';

  @override
  String get petsEditFormTitle => 'Borrador del perfil';

  @override
  String get petsEditSubmit => 'Guardar cambios';

  @override
  String get petsEditUnsyncedSnack =>
      'Los cambios se han guardado en el teléfono, pero no en el servidor. Abre el perfil y toca Reintentar.';

  @override
  String get petsEditDeleteTitle => '¿Eliminar este perfil?';

  @override
  String petsEditDeleteMessage(String name) {
    return 'El perfil de \"$name\" se eliminará definitivamente junto con sus datos.';
  }

  @override
  String get petsEditDeleteConfirm => 'Eliminar';

  @override
  String get petsEditDeleteAction => 'Eliminar perfil';

  @override
  String get petsEditMemorialTitle => '¿Mover a recuerdos?';

  @override
  String petsEditMemorialMessage(String name) {
    return '\"$name\" saldrá de la lista Mascotas y se conservará en Recuerdos con su perfil y fotos.';
  }

  @override
  String get petsEditMemorialConfirm => 'Mover';

  @override
  String get petsEditMemorialAction => 'Mover a recuerdos';

  @override
  String get petsFormAddSpecies => 'Añadir especie';

  @override
  String get petsFormIdentityColor => 'Color identificativo';

  @override
  String get petsFormNameLabel => 'Nombre';

  @override
  String get petsFormNameHint => 'Moka';

  @override
  String get petsFormNameError => 'Introduce el nombre de la mascota.';

  @override
  String get petsFormSpeciesLabel => 'Tipo de animal';

  @override
  String get petsFormSpeciesHint => 'Selecciona el tipo de animal';

  @override
  String get petsFormSpeciesError => 'Selecciona el tipo de animal.';

  @override
  String get petsFormProfileType => '¿Qué quieres registrar?';

  @override
  String get petsFormFishSingleTitle => 'Pez';

  @override
  String get petsFormFishSingleBody =>
      'Un solo pez, elegido por especie (ej. betta, pez dorado)';

  @override
  String get petsFormFishAquariumBody =>
      'Un acuario con varias especies y varios ejemplares, machos y hembras';

  @override
  String get petsFormAquariumPopulation => 'Población del acuario';

  @override
  String get petsFormNoSpeciesYet => 'Aún no se ha añadido ninguna especie.';

  @override
  String get petsFormAquariumNeedsSpecies =>
      'Añade al menos una especie al acuario.';

  @override
  String get petsFormBreedLabel => 'Raza';

  @override
  String get petsFormBreedSelectSpeciesFirst =>
      'Selecciona primero el tipo de animal';

  @override
  String get petsFormBreedSpeciesLabel => 'Especie';

  @override
  String get petsFormBreedRequired => 'Elige la raza.';

  @override
  String get petsFormBreedSpeciesRequired => 'Elige la especie.';

  @override
  String get petsFormBreedTextRequired => 'Escribe la raza.';

  @override
  String get petsFormBreedSpeciesTextRequired => 'Escribe la especie.';

  @override
  String get petsFormBreedSpeciesPlaceholder => 'Selecciona una especie';

  @override
  String get petsFormOtherSpeciesDialogTitle => '¿Qué especie?';

  @override
  String get petsFormBreedPlaceholder => 'Selecciona una raza';

  @override
  String get petsFormBreedSearchHint => 'Buscar una raza';

  @override
  String get petsFormBreedSearchHintScientific =>
      'Buscar (también por nombre científico)';

  @override
  String get petsFormOtherBreedLabel => '¿Qué raza?';

  @override
  String get petsFormOtherBreedHint => 'Ej. cruce de caniche';

  @override
  String get petsFormOtherSpeciesLabel => '¿Qué especie?';

  @override
  String get petsFormOtherSpeciesHint => 'Ej. nombre común o científico';

  @override
  String get petsFormDogSizeLabel => 'Tamaño (opcional)';

  @override
  String get petsFormDogSizeHint => 'Selecciona un tamaño';

  @override
  String get petsFormBirthDateLabel => 'Fecha de nacimiento';

  @override
  String get petsFormBirthDateHint => 'dd/mm/aaaa';

  @override
  String get petsFormBirthDateRequired => 'Selecciona la fecha de nacimiento.';

  @override
  String get petsFormBirthDateInvalid => 'Fecha no válida (dd/mm/aaaa).';

  @override
  String get petsFormBirthDateFuture =>
      'La fecha de nacimiento no puede estar en el futuro.';

  @override
  String get petsFormSexLabel => 'Sexo';

  @override
  String get petsFormSexHint => 'Seleccionar';

  @override
  String get petsFormSexUnknown => 'Desconocido';

  @override
  String get petsFormWeightLabelKg => 'Peso (opcional, kg)';

  @override
  String get petsFormWeightLabelLb => 'Peso (opcional, lb)';

  @override
  String get petsFormWeightHintKg => 'Ej. 18,4';

  @override
  String get petsFormWeightLabelG => 'Peso (opcional, g)';

  @override
  String get petsFormWeightHintG => 'Ej. 35';

  @override
  String get petsFormWeightHintLb => 'Ej. 40,5';

  @override
  String get petsFormWeightInvalid => 'Introduce un peso válido.';

  @override
  String get petsFormWeightPositive => 'El peso debe ser mayor que cero.';

  @override
  String get petsFormNotesLabel => 'Notas';

  @override
  String get petsFormNotesHint =>
      'Añade notas breves sobre dieta, medicamentos o comportamiento.';

  @override
  String get petsFormSaving => 'Guardando…';

  @override
  String get petsFormPhotoAdd => 'Añadir foto';

  @override
  String get petsFormPhotoChange => 'Cambiar foto';

  @override
  String get petsFormPhotoRemove => 'Eliminar';

  @override
  String get petsFormHabitatLength => 'Longitud';

  @override
  String get petsFormHabitatWidth => 'Anchura';

  @override
  String get petsFormHabitatHeight => 'Altura';

  @override
  String get petsFormHabitatUsGallons => 'Galones de EE. UU.';

  @override
  String get petsFormHabitatLiters => 'Litros';

  @override
  String get petsFormHabitatVolumeHint =>
      'Calculados a partir de las dimensiones y modificables';

  @override
  String get petsFormHabitatTemperature => 'Temperatura';

  @override
  String get petsFormHabitatTemperatureHintF => 'Ej. 75-79°F';

  @override
  String get petsFormHabitatTemperatureHintC => 'Ej. 24-26°C';

  @override
  String get petsFormHabitatSubstrate => 'Sustrato';

  @override
  String get petsFormHabitatSubstrateHint => 'Ej. grava fina, fibra de coco';

  @override
  String get petsFormHabitatEquipment => 'Equipamiento';

  @override
  String get petsFormHabitatEquipmentHint =>
      'Filtro, iluminación, calentador, plantas, lámpara UVB, perchas…';

  @override
  String get petsDetailTitleFallback => 'Detalles de la mascota';

  @override
  String get petsDetailGalleryTooltip => 'Galería de fotos';

  @override
  String get petsDetailLoading => 'Cargando los detalles…';

  @override
  String get petsDetailErrorTitle => 'Detalles no disponibles';

  @override
  String get petsDetailErrorDefault =>
      'Este perfil de mascota no está disponible ahora.';

  @override
  String get petsDetailBackToList => 'Volver a la lista';

  @override
  String get petsDetailEmptyTitle => 'Ninguna mascota seleccionada';

  @override
  String get petsDetailEmptySubtitle =>
      'Elige un perfil de la lista para ver detalles, chats e informes.';

  @override
  String get petsDetailTabReminders => 'Recordatorios';

  @override
  String get petsDetailTabChat => 'Chat';

  @override
  String get petsDetailTabRecords => 'Informes';

  @override
  String get petsDetailTabWalks => 'Paseos';

  @override
  String get petsDetailHabitatTapForDetails => 'Toca para ver los detalles';

  @override
  String get petsDetailHabitatDimensions => 'Dimensiones';

  @override
  String get petsDetailHabitatVolume => 'Volumen';

  @override
  String get petsDetailPopulation => 'Población';

  @override
  String get petsDetailRemindersNew => 'Nuevo recordatorio';

  @override
  String petsDetailRemindersEmpty(String petName) {
    return 'Aún no hay recordatorios para $petName.';
  }

  @override
  String get petsDetailChatNew => 'Nuevo chat';

  @override
  String petsDetailChatEmpty(String petName) {
    return 'Aún no hay conversaciones para $petName.';
  }

  @override
  String petsDetailChatDeleteFailed(String error) {
    return 'El chat se ha eliminado aquí, pero no del servidor: $error';
  }

  @override
  String get petsDetailChatDeleteTitle => '¿Eliminar este chat?';

  @override
  String petsDetailChatDeleteMessage(String title) {
    return '\"$title\" se eliminará definitivamente.';
  }

  @override
  String get petsDetailChatLimitTitle => 'Límite de chats alcanzado';

  @override
  String petsDetailChatLimitMessage(int max, String petName) {
    return 'Puedes tener hasta $max conversaciones activas para $petName. Elimina un chat para abrir uno nuevo.';
  }

  @override
  String get petsDetailChatLimitOk => 'Entendido';

  @override
  String get petsDetailRecordsSendTitle => 'Enviar archivo';

  @override
  String get petsDetailRecordsSendSubtitle =>
      'Elige un documento para enviarlo por correo, WhatsApp u otra aplicación.';

  @override
  String petsDetailRecordShareText(String title, String source, String date) {
    return '📄 $title\n$source · $date\n\nCompartido desde VetApp';
  }

  @override
  String get petsDetailShareUnavailable =>
      'La función de compartir no está disponible en este dispositivo.';

  @override
  String get petsDetailRecordsUpload => 'Subir archivo';

  @override
  String get petsDetailRecordsSend => 'Enviar';

  @override
  String petsDetailRecordsEmpty(String petName) {
    return 'Aún no hay documentos para $petName.';
  }

  @override
  String get petsDetailRecordsLoadError =>
      'No se pueden leer los informes. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String petsDetailSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '1 seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get petsDetailWalksStart => 'Iniciar paseo';

  @override
  String get petsDetailWalksBadges => 'Insignias';

  @override
  String petsDetailWalksEmpty(String petName) {
    return 'Aún no hay paseos para $petName.';
  }

  @override
  String get petsDetailWalksRecords => 'Récords 🏆';

  @override
  String get petsDetailWalksFavorites => 'Favoritos ⭐';

  @override
  String get petsDetailWalksRecent => 'Recientes';

  @override
  String get petsDetailWalkLongest => 'Más largo';

  @override
  String get petsDetailWalkLongestDuration => 'Mayor duración';

  @override
  String get petsDetailWalkLongestAndDuration => 'Más largo · Mayor duración';

  @override
  String petsDetailWalkStatusActive(String distance, String elapsed) {
    return 'Paseo en curso · $distance · $elapsed';
  }

  @override
  String petsDetailWalkStatusPaused(String distance, String elapsed) {
    return 'En pausa · $distance · $elapsed';
  }

  @override
  String get petsDetailWalkUnfavoriteTitle => '¿Quitar de favoritos?';

  @override
  String get petsDetailWalkUnfavoriteMessage =>
      'Si no es también un récord o uno de los 3 últimos paseos, su mapa podría eliminarse en la próxima limpieza automática.';

  @override
  String get petsDetailWalkUnfavoriteConfirm => 'Quitar de favoritos';

  @override
  String get petsDetailWalkDeleteTitle => '¿Eliminar este paseo?';

  @override
  String petsDetailWalkDeleteMessage(String date, String distance) {
    return 'El paseo del $date ($distance) se eliminará definitivamente.';
  }

  @override
  String petsDetailWalkSteps(int count) {
    return '~$count pasos';
  }

  @override
  String get petsDetailUnsyncedBanner =>
      'Sin sincronizar: los cambios solo están en este teléfono.';

  @override
  String get petsDetailUnsyncedRetryFailed =>
      'El servidor sigue sin estar disponible. Inténtalo más tarde.';

  @override
  String get petsScaffoldBadge => 'Mascota';

  @override
  String get petsLoadingDefaultLabel => 'Cargando mascotas…';

  @override
  String get petsLoadingSubtitle =>
      'Espera un momento mientras preparamos la pantalla.';

  @override
  String get petsDemoDeleteFailed =>
      'No pude eliminar el perfil. Inténtalo de nuevo.';

  @override
  String get petsDemoNewProfileNote =>
      'Perfil recién creado, listo para la próxima visita.';

  @override
  String get petsDemoNextVisitToPlan => 'Por programar';

  @override
  String get petsValueSpeciesDog => 'Perro';

  @override
  String get petsValueSpeciesCat => 'Gato';

  @override
  String get petsValueSpeciesSmallMammals => 'Pequeños mamíferos';

  @override
  String get petsValueSpeciesBird => 'Ave';

  @override
  String get petsValueSpeciesReptiles => 'Reptiles y anfibios';

  @override
  String get petsValueSpeciesFish => 'Pez';

  @override
  String get petsValueSpeciesOther => 'Otro';

  @override
  String get petsValueSpeciesAll => 'Todos';

  @override
  String get petsValueSexMale => 'Macho';

  @override
  String get petsValueSexFemale => 'Hembra';

  @override
  String get petsValueSexMaleIntact => 'Macho entero';

  @override
  String get petsValueSexMaleNeutered => 'Macho castrado';

  @override
  String get petsValueSexFemaleIntact => 'Hembra entera';

  @override
  String get petsValueSexFemaleSpayed => 'Hembra esterilizada';

  @override
  String get petsValueDogSizeToy => 'Toy';

  @override
  String get petsValueDogSizeSmall => 'Pequeño';

  @override
  String get petsValueDogSizeMedium => 'Mediano';

  @override
  String get petsValueDogSizeLarge => 'Grande';

  @override
  String get petsValueDogSizeGiant => 'Gigante';

  @override
  String get petsListTitle => 'Animales';

  @override
  String get petsListMemoriesTooltip => 'Recuerdos';

  @override
  String get petsListLoading => 'Cargando la lista de mascotas…';

  @override
  String get petsListErrorTitle => 'Mascotas no disponibles';

  @override
  String get petsListErrorDefault =>
      'Ahora mismo no se pueden cargar los perfiles de mascotas.';

  @override
  String get petsListEmptyTitle => 'Aún no hay mascotas';

  @override
  String get petsListEmptySubtitle =>
      'Crea el primer perfil para controlar la salud, las notas y las fechas importantes.';

  @override
  String get petsListEmptyAction => 'Crear mascota';

  @override
  String get petsListFilterEmpty => 'Ninguna mascota coincide con este filtro.';

  @override
  String get petsMemoriesRemoveTitle => '¿Eliminar definitivamente?';

  @override
  String petsMemoriesRemoveBody(String name) {
    return 'El recuerdo de \"$name\" se eliminará sin posibilidad de recuperación.';
  }

  @override
  String get petsMemoriesRemoveConfirm => 'Eliminar';

  @override
  String get petsMemoriesTitle => 'Recuerdos';

  @override
  String get petsMemoriesSubtitle =>
      'Los perfiles de las mascotas que compartieron vuestro camino.';

  @override
  String get petsMemoriesEmpty => 'Aún no hay recuerdos guardados.';

  @override
  String petsMemoriesWithUsUntil(String date) {
    return 'Con nosotros hasta el $date';
  }

  @override
  String petsMemoriesWithUsRange(String from, String to) {
    return 'Con nosotros desde $from hasta $to';
  }

  @override
  String get petsMemoriesComingSoon =>
      'Próximamente: vuestros mejores momentos juntos, como los paseos más largos o los logros alcanzados, reunidos aquí.';

  @override
  String get petsMediaGalleryTitle => 'Galería';

  @override
  String get petsMediaFoldersLoading => 'Cargando carpetas…';

  @override
  String get petsMediaFoldersEmpty =>
      'Añade un animal para crear su carpeta de fotos.';

  @override
  String get petsMediaFolderCounting => 'Contando fotos…';

  @override
  String petsMediaCountPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String petsMediaCountVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos',
      one: '1 vídeo',
    );
    return '$_temp0';
  }

  @override
  String petsMediaCountPhotosAndVideos(String photos, String videos) {
    return '$photos · $videos';
  }

  @override
  String get petsMediaVideoSemantics => 'Vídeo';

  @override
  String get petsMediaDeleteVideoTitle => '¿Eliminar este vídeo?';

  @override
  String get petsMediaDeletePhotoTitle => '¿Eliminar esta foto?';

  @override
  String get petsMediaDeleteVideoBody =>
      'El vídeo se eliminará definitivamente de la galería.';

  @override
  String get petsMediaDeletePhotoBody =>
      'La foto se eliminará definitivamente de la galería.';

  @override
  String get petsMediaOperationFailed =>
      'No se pudo completar la operación. Inténtalo de nuevo.';

  @override
  String get petsMediaSetAsProfile => 'Establecer como foto de perfil';

  @override
  String get petsMediaDeleteVideoAction => 'Eliminar vídeo';

  @override
  String get petsMediaDeletePhotoAction => 'Eliminar foto';

  @override
  String get petsMediaImportFromGallery => 'Importar desde la galería';

  @override
  String get petsMediaImportFromGalleryHint =>
      'Fotos y vídeos, también varios archivos';

  @override
  String get petsMediaTakePhoto => 'Hacer foto';

  @override
  String get petsMediaRecordVideo => 'Grabar vídeo';

  @override
  String petsMediaRecordVideoLimit(int seconds) {
    return 'Hasta $seconds segundos';
  }

  @override
  String petsMediaGalleryOf(String name) {
    return 'Galería de $name';
  }

  @override
  String get petsMediaGalleryEmpty =>
      'Todavía no hay fotos ni vídeos. Usa el botón «Añadir» de abajo.';

  @override
  String get petsMediaVideoPlaybackFailed => 'No puedo reproducir este vídeo.';

  @override
  String get petsMediaVideoLoading => 'Cargando vídeo...';

  @override
  String get petsMediaCancelling => 'Cancelando...';

  @override
  String get petsMediaPreparingFile => 'Preparando archivo...';

  @override
  String petsMediaPreparingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Preparando $count archivos...',
      one: 'Preparando archivo...',
    );
    return '$_temp0';
  }

  @override
  String get petsMediaUploadingFile => 'Subiendo archivo...';

  @override
  String petsMediaUploadingProgress(int current, int total) {
    return 'Subiendo $current de $total...';
  }

  @override
  String get petsMediaUploadingVideo => 'Subiendo vídeo...';

  @override
  String petsMediaUploadingVideoOf(int current, int total) {
    return 'Subiendo vídeo $current de $total...';
  }

  @override
  String petsMediaReducingVideo(int percent) {
    return 'Comprimiendo vídeo... $percent%';
  }

  @override
  String petsMediaReducingVideoOf(int current, int total, int percent) {
    return 'Comprimiendo vídeo $current de $total... $percent%';
  }

  @override
  String petsMediaImportJoin(String first, String second) {
    return '$first y $second';
  }

  @override
  String petsMediaImportDone(String list) {
    return 'Subidos: $list';
  }

  @override
  String get petsMediaImportCancelled => 'Carga cancelada.';

  @override
  String petsMediaImportCancelledWith(String done) {
    return 'Carga cancelada. $done.';
  }

  @override
  String get petsMediaImportNothingToAdd => 'Nada que añadir.';

  @override
  String petsMediaImportProblemMore(String problem, int count) {
    return '$problem ($count más sin añadir)';
  }

  @override
  String petsMediaImportDoneWithProblem(String done, String problem) {
    return '$done. $problem';
  }

  @override
  String petsMediaPhotoAddedTo(String name) {
    return 'Foto añadida a la galería de $name';
  }

  @override
  String petsMediaVideoAddedTo(String name) {
    return 'Vídeo añadido a la galería de $name';
  }

  @override
  String petsMediaImportFileFailed(String file) {
    return 'No pude subir $file.';
  }

  @override
  String get petsMediaImportUnnamedFile => 'un archivo';

  @override
  String get petsMediaPhotoSaveOffline =>
      'No se pueden guardar fotos sin conexión.';

  @override
  String get petsMediaVideoSaveOffline =>
      'No se pueden guardar vídeos sin conexión.';

  @override
  String petsMediaImportRefused(String file, String message) {
    return '$file: $message';
  }

  @override
  String get petsMediaVideoUnsupportedFormat =>
      'Formato de vídeo no compatible: usa MP4 o MOV.';

  @override
  String petsMediaVideoTooBigSource(int size, int max) {
    return 'Vídeo demasiado grande ($size MB): el máximo es $max MB.';
  }

  @override
  String petsMediaVideoTooBigBrowser(int size, int max) {
    return 'Vídeo demasiado grande ($size MB): el máximo en el navegador es $max MB. La app móvil comprime los vídeos automáticamente.';
  }

  @override
  String get petsMediaVideoUnreadable => 'No puedo leer este vídeo.';

  @override
  String petsMediaVideoTooLong(int seconds) {
    return 'Vídeo demasiado largo: el máximo es $seconds segundos.';
  }

  @override
  String petsMediaVideoTooBigReduced(int size, int max) {
    return 'Incluso comprimido, el vídeo ocupa $size MB (máximo $max MB). Prueba con un clip más corto.';
  }

  @override
  String petsMediaVideoTooBigNotReduced(int size, int max) {
    return 'No pude comprimir el vídeo y ocupa $size MB (máximo $max MB). Prueba con un clip más corto.';
  }

  @override
  String petsConsentSemanticsExpanded(String name) {
    return 'Consentimiento para leer el historial de $name. Toca para cerrar el texto completo';
  }

  @override
  String petsConsentSemanticsCollapsed(String name) {
    return 'Consentimiento para leer el historial de $name. Toca para leer el texto completo';
  }

  @override
  String petsConsentCardTitle(String name) {
    return 'Historial clínico de $name';
  }

  @override
  String get petsConsentReadHow => 'Lee cómo se utiliza';

  @override
  String petsConsentSwitchSemantics(String name) {
    return 'Permite al asistente leer el historial de $name';
  }

  @override
  String get petsConsentWithoutConsent =>
      'Sin consentimiento, el asistente no ve los títulos ni el contenido de los informes.';

  @override
  String get petsConsentSaveFailed =>
      'No pude guardar el consentimiento. Inténtalo de nuevo.';

  @override
  String get petsConsentStatusUnavailable =>
      'Estado del consentimiento no disponible: comprueba la conexión.';

  @override
  String get petsConsentSlowConnection =>
      'Conexión lenta. El consentimiento no se guardó. Inténtalo de nuevo.';

  @override
  String get petsConsentOffline =>
      'Estás sin conexión: el consentimiento no se guardó. Inténtalo con conexión.';

  @override
  String get placesDetailBarrierFence => 'Vallado';

  @override
  String get placesDetailBarrierWall => 'Cerrado con muro';

  @override
  String get placesDetailBarrierHedge => 'Delimitado por seto';

  @override
  String get placesDetailSurfaceGrass => 'Suelo de césped';

  @override
  String get placesDetailSurfaceGround => 'Suelo de tierra';

  @override
  String get placesDetailSurfaceSand => 'Suelo de arena';

  @override
  String get placesDetailSurfaceGravel => 'Suelo de grava';

  @override
  String get placesDetailSurfaceAsphalt => 'Suelo asfaltado';

  @override
  String get placesDetailSurfacePaved => 'Suelo pavimentado';

  @override
  String get placesDetailAccessFree => 'Acceso público';

  @override
  String get placesDetailAccessPermissive => 'Acceso permitido';

  @override
  String get placesDetailAccessCustomers => 'Solo clientes';

  @override
  String get placesDetailAccessPrivate => 'Área privada';

  @override
  String get placesDetailWheelchairYes => 'Accesible en silla de ruedas';

  @override
  String get placesDetailWheelchairLimited =>
      'Accesibilidad parcial en silla de ruedas';

  @override
  String get placesDetailWheelchairNo => 'No accesible en silla de ruedas';

  @override
  String get placesDetailDrinkingWaterYes => 'Agua potable';

  @override
  String get placesDetailDrinkingWaterNo => 'Sin agua potable';

  @override
  String get placesDetailLitYes => 'Iluminado';

  @override
  String get placesDetailLitNo => 'Sin iluminación';

  @override
  String get placesDetailDogUnleashed => 'Perros sin correa';

  @override
  String get placesDetailAdoptionYes => 'Adopciones disponibles';

  @override
  String get placesDetailAdoptionNo => 'No ofrece adopciones';

  @override
  String placesPendingDogPark(String progress) {
    return 'Informado por usuarios: comprueba que sea un área pública ($progress)';
  }

  @override
  String placesPendingPlace(String progress) {
    return 'Informado por usuarios · pendiente de confirmación ($progress)';
  }

  @override
  String placesMailRemoveSubject(String id) {
    return 'Parque canino que retirar del radar ($id)';
  }

  @override
  String placesMailRemoveBody(String name, String position, String id) {
    return 'Esta área informada por usuarios no es un parque canino público.\n\nNombre: $name\nUbicación: $position\nIdentificador: $id\n\nMotivo: ';
  }

  @override
  String get placesWithdrawTitle => '¿Retirar el informe?';

  @override
  String get placesWithdrawBody =>
      'El informe se eliminará y dejará de ser visible para todos.';

  @override
  String get placesWithdrawConfirm => 'Retirar';

  @override
  String get placesWithdrawnSnack => 'Informe retirado.';

  @override
  String get placesVoteConfirmedSnack => 'Gracias, confirmación registrada.';

  @override
  String get placesVoteDeniedSnack => 'Gracias, registrado.';

  @override
  String placesRatedSnack(int stars) {
    return 'Valoración registrada: $stars de 5.';
  }

  @override
  String get placesReportsInactiveSnack =>
      'Los informes no están activos ahora.';

  @override
  String get placesReportProblemTitle => '¿Qué problema tiene este lugar?';

  @override
  String get placesReportAlreadyKnown =>
      'Ya se había informado: tu informe cuenta como confirmación.';

  @override
  String get placesReportSent =>
      'Informe enviado. Se aplicará cuando otros usuarios lo confirmen.';

  @override
  String get placesSheetPendingQuestion => '¿Este lugar existe realmente aquí?';

  @override
  String get placesSheetNotPublicWrite => '¿No es un área pública? Escríbenos';

  @override
  String placesSheetClosedReported(String progress) {
    return 'Informado como cerrado ($progress)';
  }

  @override
  String get placesSheetClosedQuestion => '¿Ha cerrado realmente?';

  @override
  String placesSheetOpeningHours(String hours) {
    return 'Horario indicado: $hours';
  }

  @override
  String get placesActionCall => 'Llamar';

  @override
  String get placesActionDirections => 'Indicaciones';

  @override
  String get placesActionWebsite => 'Sitio web';

  @override
  String get placesDisclaimerCommunity =>
      'Lugar informado por usuarios: compruébalo antes de ir.';

  @override
  String get placesDisclaimerClinic =>
      'En caso de urgencia, llama antes de salir: los horarios y contactos proceden de datos abiertos y no están verificados por VetApp.';

  @override
  String get placesDisclaimerGeneric =>
      'Los horarios y contactos proceden de datos abiertos y VetApp no los verifica.';

  @override
  String placesSourceLine(String source) {
    return 'Fuente: $source';
  }

  @override
  String placesAlsoIn(String sources) {
    return 'También aparece en: $sources';
  }

  @override
  String get placesReportProblemAction => 'Informar de un problema';

  @override
  String get placesBannerWithdrawing => 'Retirando informe…';

  @override
  String get placesBannerYouReported =>
      'Lo has informado tú: se necesitan confirmaciones de otros usuarios.';

  @override
  String get placesBannerConfirmedSaving => 'Lo has confirmado. Guardando…';

  @override
  String get placesBannerConfirmedChange =>
      'Lo has confirmado. Puedes cambiar de opinión.';

  @override
  String get placesBannerDeniedSaving =>
      'Has indicado que no es así. Guardando…';

  @override
  String get placesBannerDeniedChange =>
      'Has indicado que no es así. Puedes cambiar de opinión.';

  @override
  String get placesBannerWithdrawButton => 'Retirar mi informe';

  @override
  String get placesBannerConfirm => 'Confirmar';

  @override
  String get placesBannerDeny => 'No es así';

  @override
  String placesVotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
    );
    return '$_temp0';
  }

  @override
  String placesRatingAverage(String average, String votes) {
    return 'Valoración de la comunidad: $average de 5 · $votes';
  }

  @override
  String get placesRatingNone => 'Valoración de la comunidad: aún no hay votos';

  @override
  String placesRatingBelowThreshold(String votes) {
    return 'Valoración de la comunidad: $votes · la media aparece a partir de 3 votos';
  }

  @override
  String placesRateStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dar $count estrellas',
      one: 'Dar 1 estrella',
    );
    return '$_temp0';
  }

  @override
  String placesRatingSaving(int stars) {
    return 'Tu valoración: $stars de 5. Guardando…';
  }

  @override
  String placesRatingYours(int stars) {
    return 'Tu valoración: $stars de 5. Toca una estrella para cambiarla.';
  }

  @override
  String get placesRatingPrompt =>
      '¿Qué tal es este parque canino? Toca una estrella para valorarlo.';

  @override
  String get placesExpiryToday => 'Caduca hoy si nadie lo confirma.';

  @override
  String placesExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Caduca en $days días si nadie lo confirma.',
      one: 'Caduca en 1 día si nadie lo confirma.',
    );
    return '$_temp0';
  }

  @override
  String get placesProblemClosed => 'Ha cerrado o ya no existe';

  @override
  String get placesProblemDuplicate => 'Es un duplicado de otro lugar';

  @override
  String get placesProblemWrongPosition => 'La ubicación es incorrecta';

  @override
  String get placesCategoryVeterinary => 'Veterinarios';

  @override
  String get placesCategoryShop => 'Tiendas';

  @override
  String get placesCategoryDogPark => 'Parques caninos';

  @override
  String get placesCategoryShelter => 'Refugios y adopciones';

  @override
  String get placesCategoryAssociation => 'Asociaciones';

  @override
  String get placesCategoryGrooming => 'Peluquerías';

  @override
  String get placesCategoryHotel => 'Residencias';

  @override
  String get placesCategorySchool => 'Adiestramiento';

  @override
  String get placesCategoryPetSitting => 'Cuidador de mascotas';

  @override
  String get placesCategoryBreeder => 'Criadores';

  @override
  String get placesCategoryOther => 'Otros servicios';

  @override
  String get placesTypeVeterinary => 'Veterinario';

  @override
  String get placesTypeGrooming => 'Peluquería';

  @override
  String get placesTypeShop => 'Tienda de mascotas';

  @override
  String get placesTypeSchool => 'Adiestramiento';

  @override
  String get placesTypePetSitting => 'Cuidador de mascotas';

  @override
  String get placesTypeBreeder => 'Criador';

  @override
  String get placesTypeHotel => 'Residencia de mascotas';

  @override
  String get placesTypeDogPark => 'Parque canino';

  @override
  String get placesTypeShelter => 'Refugio de animales';

  @override
  String get placesTypeAssociation => 'Asociación animalista';

  @override
  String get placesTypeOther => 'Servicio para mascotas';

  @override
  String get placesHours247 => 'Indicado como abierto las 24 horas';

  @override
  String get placesHoursHolidays => 'Festivos';

  @override
  String get placesHoursClosed => 'cerrado';

  @override
  String get placesSourcesTitle => 'Fuentes de datos';

  @override
  String get placesSourcesIntro =>
      'Los lugares del radar proceden de datos abiertos. Cada ficha indica su fuente. Los horarios y contactos pueden estar desactualizados.';

  @override
  String get placesSourcesNoContact =>
      '¿Has encontrado un dato incorrecto? Usa «Informar de un problema» en la ficha.';

  @override
  String placesSourcesContact(String email) {
    return '¿Hay un dato incorrecto o eres el titular y quieres corregir o retirar una ficha? Escribe a $email.';
  }

  @override
  String placesSourceLicense(String license) {
    return 'Licencia: $license';
  }

  @override
  String placesSourceVersion(String release, String date) {
    return 'Versión $release, importada el $date';
  }

  @override
  String get placesSourceLicenseLink => 'Licencia y condiciones';

  @override
  String get placesSourceOsmDescription =>
      'Mapa libre mantenido por voluntarios. Incluye parques caninos y algunos veterinarios, tiendas y servicios, con detalles añadidos por voluntarios.';

  @override
  String get placesSourceOvertureDescription =>
      'Directorio abierto de negocios. Incluye veterinarios, peluquerías, tiendas, residencias y adiestradores que no aparecen en OpenStreetMap.';

  @override
  String get placesSourceBolognaDescription =>
      'Lista oficial de áreas caninas del Ayuntamiento de Bolonia.';

  @override
  String get placesSourceTorinoDescription =>
      'Lista oficial de parques caninos de la Ciudad de Turín.';

  @override
  String get placesSourceMilanoDescription =>
      'Lista oficial de parques caninos del Ayuntamiento de Milán.';

  @override
  String get placesSourceBolognaAttribution =>
      'Ayuntamiento de Bolonia, áreas caninas (opendata.comune.bologna.it), licencia CC BY 4.0';

  @override
  String get placesSourceTorinoAttribution =>
      'Ayuntamiento de Turín, parques caninos (aperto.comune.torino.it), licencia CC BY 4.0, datos de 2019';

  @override
  String get placesSourceMilanoAttribution =>
      'Ayuntamiento de Milán, ubicación de parques caninos (dati.comune.milano.it), licencia CC BY 4.0. Incluye datos procesados CC BY 3.0 de dati.gov.it';

  @override
  String get placesSourceLicenseCcBy =>
      'Creative Commons Atribución 4.0 (CC BY 4.0)';

  @override
  String get placesSourceUsersName => 'Usuarios de VetApp';

  @override
  String get placesSourceUsersDescription =>
      'Lugares informados por usuarios y confirmados por otros usuarios.';

  @override
  String get placesSourceUsersAttribution => 'Informado por usuarios de VetApp';

  @override
  String placesMapTitle(String radius) {
    return 'Mapa · $radius';
  }

  @override
  String placesMapClusterSemantics(int count) {
    return '$count lugares cercanos';
  }

  @override
  String placesMapMarkerPending(String category, String label) {
    return '$category, pendiente de confirmación: $label';
  }

  @override
  String placesMapMarker(String category, String label) {
    return '$category: $label';
  }

  @override
  String get placesReportTitle => 'Informar de un lugar que falta';

  @override
  String get placesReportUnavailable =>
      'Los informes no están disponibles ahora. Inténtalo más tarde.';

  @override
  String get placesReportWhatIs => '¿Qué es?';

  @override
  String get placesReportNameOptional => 'Nombre (opcional)';

  @override
  String get placesReportNameLabel => 'Nombre del letrero';

  @override
  String get placesReportNameHelper =>
      'Solo el nombre: sin teléfonos, direcciones ni nombres de personas.';

  @override
  String get placesReportWhere => '¿Dónde está?';

  @override
  String get placesReportMapHint =>
      'Mueve el mapa hasta que el marcador esté sobre el lugar. La dirección se obtiene de la posición.';

  @override
  String get placesReportSubmit => 'Enviar informe';

  @override
  String placesReportFootnote(int days) {
    return 'El informe será visible para todos como pendiente de confirmación. Otros usuarios deben confirmarlo. Se elimina automáticamente si nadie lo confirma en $days días. Puedes retirarlo cuando quieras desde su ficha. Tu nombre no aparece.';
  }

  @override
  String placesReportSentExpiry(int days) {
    return 'Informe enviado. Se eliminará si nadie lo confirma en $days días.';
  }

  @override
  String get placesRulesTitle => 'Antes de informar o votar';

  @override
  String get placesRulesCheckbox =>
      'He leído las reglas e informaré o votaré de buena fe.';

  @override
  String get placesRulesAccept => 'Aceptar';

  @override
  String get placesRulesFallback =>
      'Informa solo de lo que hayas comprobado en persona. Para negocios, escribe solo el nombre del letrero, sin teléfonos, direcciones privadas ni datos de otras personas. Los informes quedan pendientes hasta que otros usuarios los confirmen. Los informes falsos o repetidos pueden causar la suspensión de la cuenta. Los informes y votos se publican sin tu nombre.';

  @override
  String get placesErrSignedOutContribute =>
      'Inicia sesión para informar o votar.';

  @override
  String get placesErrOperationFailed =>
      'No se pudo completar la operación. Inténtalo de nuevo.';

  @override
  String get placesErrTimeout =>
      'La solicitud tardó demasiado. Inténtalo de nuevo.';

  @override
  String get placesErrNotConfigured =>
      'Vista previa sin backend: los lugares mostrados son ejemplos.';

  @override
  String get placesErrSignedOut =>
      'Inicia sesión para ver servicios cercanos para mascotas.';

  @override
  String get placesErrPreparing =>
      'Los servicios de esta zona aún se están preparando. Inténtalo en unos instantes.';

  @override
  String get placesErrSessionExpired =>
      'Tu sesión ya no es válida: sal y vuelve a iniciar sesión para ver servicios cercanos.';

  @override
  String get placesErrLoadFailed =>
      'No pude cargar los servicios cercanos. Inténtalo de nuevo.';

  @override
  String get placesBackendRulesRequired =>
      'Acepta las reglas antes de informar o votar.';

  @override
  String get placesBackendReportClosed => 'Este informe ya está cerrado.';

  @override
  String get placesBackendReportExpired =>
      'Este informe caducó porque nadie lo confirmó.';

  @override
  String get placesBackendOwnReportVote =>
      'No puedes confirmar tu propio informe.';

  @override
  String get placesBackendKindNotActive =>
      'Este tipo de informe no está activo.';

  @override
  String get placesBackendCategoryNotReportable =>
      'No se puede informar de esta categoría.';

  @override
  String get placesBackendTargetRequired =>
      'Indica el lugar al que se refiere el informe.';

  @override
  String get placesBackendPendingUseDeny =>
      'Para un lugar pendiente de confirmación, usa «No es así» en su ficha.';

  @override
  String get placesBackendAlreadyReported => 'Ya has enviado este informe.';

  @override
  String placesBackendDailyLimit(int count) {
    return 'Puedes enviar como máximo $count informes al día.';
  }

  @override
  String get placesBackendReportNotFound => 'Informe no encontrado.';

  @override
  String get placesBackendWithdrawOwnOnly =>
      'Solo puedes retirar tu propio informe.';

  @override
  String get placesBackendWithdrawClosed =>
      'Este informe ya está cerrado y no se puede retirar.';

  @override
  String get placesBackendRatingsOff => 'Las valoraciones no están activas.';

  @override
  String get placesBackendRatePublicOnly =>
      'Solo se pueden valorar parques caninos públicos.';

  @override
  String get placesBackendDogParkNotFound => 'Parque canino no encontrado.';

  @override
  String get placesBackendContributionsOff =>
      'Los informes y votos aún no están activos.';

  @override
  String get placesBackendNameRequired =>
      'Escribe el nombre del negocio tal como aparece en el letrero.';

  @override
  String placesBackendNameTooLong(int count) {
    return 'El nombre puede tener como máximo $count caracteres.';
  }

  @override
  String get placesBackendNameNoContacts =>
      'No incluyas teléfonos, correos ni sitios web en el nombre.';

  @override
  String get placesBackendNameBlockedWords =>
      'El nombre contiene palabras no permitidas.';

  @override
  String get eventsTitle => 'Eventos';

  @override
  String get eventsSearching => 'Buscando eventos…';

  @override
  String get eventsAllRegions => 'Todas las regiones';

  @override
  String get eventsAllTypes => 'Todos los tipos';

  @override
  String get eventsReset => 'Restablecer';

  @override
  String get eventsDisclaimer =>
      'Las fechas y lugares pueden cambiar: consulta siempre el sitio del organizador.';

  @override
  String get eventsPickRegionTitle => 'Región';

  @override
  String get eventsPickTypeTitle => 'Tipo de evento';

  @override
  String get eventsPickDatesHelp => 'Elige un período';

  @override
  String get eventsPickDatesSave => 'Aplicar';

  @override
  String get eventsStatusCancelled => 'Cancelado';

  @override
  String get eventsStatusPostponed => 'Aplazado';

  @override
  String eventsOrganizedBy(String name) {
    return 'Organizado por $name';
  }

  @override
  String get eventsSuggestAction => 'Sugerir un evento';

  @override
  String get eventsSuggestTitle => 'Sugerir un evento';

  @override
  String get eventsSuggestIntro =>
      '¿Conoces una feria o un evento para mascotas que no aparece aquí? Rellena los datos: lo comprobamos en el sitio del organizador antes de publicarlo.';

  @override
  String get eventsSuggestPrivacy =>
      'Escribe solo información sobre el evento: sin nombres de personas, correos ni teléfonos.';

  @override
  String get eventsSuggestFieldTitle => 'Nombre del evento';

  @override
  String get eventsSuggestFieldType => 'Tipo de evento';

  @override
  String get eventsSuggestFieldDates => 'Fechas';

  @override
  String get eventsSuggestPickDates => 'Elige las fechas';

  @override
  String get eventsSuggestFieldCity => 'Ciudad';

  @override
  String get eventsSuggestFieldProvince => 'Provincia (siglas, ej. MO)';

  @override
  String get eventsSuggestFieldVenue =>
      'Lugar, por ejemplo el recinto ferial (opcional)';

  @override
  String get eventsSuggestFieldLink => 'Enlace a la página del evento';

  @override
  String get eventsSuggestRequired => 'Campo obligatorio';

  @override
  String get eventsSuggestInvalidLink =>
      'Introduce una dirección que empiece por http:// o https://';

  @override
  String get eventsSuggestInvalidProvince => 'Usa las siglas de dos letras';

  @override
  String get eventsSuggestSend => 'Enviar sugerencia';

  @override
  String get eventsSuggestThanks =>
      '¡Gracias! Comprobaremos el evento antes de publicarlo.';

  @override
  String get eventsSuggestNeedLogin => 'Inicia sesión para sugerir un evento.';

  @override
  String get eventsSuggestLimit =>
      'Ya has enviado las sugerencias de hoy: inténtalo mañana.';

  @override
  String get eventsSuggestError =>
      'No pude enviar la sugerencia. Inténtalo más tarde.';

  @override
  String get eventsLoadError =>
      'No puedo cargar los eventos. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String eventsWindowDefault(int days) {
    return 'Próximos $days días';
  }

  @override
  String get eventsEmptyFiltered =>
      'No hay eventos con estos filtros en el período elegido';

  @override
  String eventsEmptyDefault(int days) {
    return 'No hay eventos en los próximos $days días';
  }

  @override
  String get eventsEmptyPeriod => 'No hay eventos en el período elegido';

  @override
  String get eventsLevelLocal => 'Local';

  @override
  String get eventsLevelProvincial => 'Provincial';

  @override
  String get eventsLevelRegional => 'Regional';

  @override
  String get eventsLevelNational => 'Nacional';

  @override
  String get eventsLevelInternational => 'Internacional';

  @override
  String get eventsTypePetFair => 'Feria de mascotas';

  @override
  String get eventsTypeDogShow => 'Exposición canina';

  @override
  String get eventsTypeBreedGathering => 'Encuentro de raza';

  @override
  String get eventsTypeCatShow => 'Exposición felina';

  @override
  String get eventsTypeWorkTrial => 'Prueba de trabajo';

  @override
  String get eventsTypeDogSport => 'Deportes caninos';

  @override
  String get eventsTypeAdoptionDay => 'Jornada de adopción';

  @override
  String get eventsTypeShelterOpenDay =>
      'Jornada de puertas abiertas del refugio';

  @override
  String get eventsTypeMicrochipDay => 'Jornada de microchip';

  @override
  String get eventsTypeVaccinationCampaign => 'Campaña de vacunación';

  @override
  String get eventsTypeGroupWalk => 'Paseo en grupo';

  @override
  String get eventsTypeCourseSeminar => 'Curso o seminario';

  @override
  String get eventsTypeMarket => 'Mercadillo';

  @override
  String get eventsTypeCharityEvent => 'Evento benéfico';

  @override
  String get eventsTypeAquariumExpo => 'Acuariofilia';

  @override
  String get eventsTypeReptileExpo => 'Terrarismo';

  @override
  String get eventsTypeBirdShow => 'Ornitología';

  @override
  String get eventsTypeEquestrian => 'Ecuestre';

  @override
  String get eventsTypeOther => 'Otro';

  @override
  String get localActivitiesKindEvent => 'Evento';

  @override
  String get localActivitiesKindService => 'Servicio';

  @override
  String get localEventsTitle => 'Cerca de mí';

  @override
  String get localEventsLocating => 'Buscando tu ubicación…';

  @override
  String get localEventsSearchingAround =>
      'Buscando qué hay cerca. La primera búsqueda en una zona puede tardar hasta un minuto.';

  @override
  String get localEventsConsentTitle => '¿Usar tu ubicación?';

  @override
  String get localEventsConsentBody =>
      'VetApp usa la ubicación del teléfono solo mientras utilizas la app para mostrar servicios cercanos. También puedes indicar una dirección.';

  @override
  String get localEventsConsentChooseAddress => 'Elegir una dirección';

  @override
  String get localEventsConsentAllow => 'Permitir';

  @override
  String get localEventsReportMissing => 'Informar de un lugar ausente';

  @override
  String get localEventsServicesHeader => 'Servicios de la zona';

  @override
  String get localEventsClinicsHeader => 'Clínicas y consultas';

  @override
  String get localEventsNoClinics =>
      'No se encontraron clínicas con estos filtros.';

  @override
  String get localEventsNoServices =>
      'No se han encontrado servicios con estos filtros.';

  @override
  String get localEventsAll => 'Todos';

  @override
  String get localEventsMapFullscreen => 'Abrir el mapa a pantalla completa';

  @override
  String get localEventsNoLocationTitle => 'Configurar una ubicación';

  @override
  String get localEventsNoLocationBody =>
      'Necesitamos tu ubicación para mostrar qué hay cerca. Permite el acceso o indica tu residencia en Ajustes → Ubicación.';

  @override
  String get localEventsOpenSettings => 'Abrir Ajustes';

  @override
  String localEventsSearchingRadius(String radius) {
    return 'Buscando servicios en $radius. La primera búsqueda en una zona puede tardar hasta un minuto.';
  }

  @override
  String get localEventsSearchingNearby =>
      'Buscando servicios en tu zona. La primera búsqueda puede tardar unos segundos.';

  @override
  String get localEventsStale =>
      'No pude actualizar los servicios de esta zona. Ves los últimos datos disponibles, que podrían estar desactualizados.';

  @override
  String localEventsPartialRadius(String radius) {
    return 'Por ahora hay servicios disponibles en $radius. Reintenta pronto para el radio completo.';
  }

  @override
  String get localEventsShowLess => 'Mostrar menos';

  @override
  String localEventsShowAllCount(int count) {
    return 'Mostrar todos ($count)';
  }

  @override
  String localEventsShowAllCategory(String category, int count) {
    return 'Mostrar todos: $category ($count)';
  }

  @override
  String localEventsCategoryNone(String category, String radius) {
    return '$category: ninguno en $radius';
  }

  @override
  String localEventsCategoryCount(String category, int count) {
    return '$category ($count)';
  }

  @override
  String localEventsSectionExpand(String section) {
    return 'Abrir $section';
  }

  @override
  String localEventsSectionCollapse(String section) {
    return 'Cerrar $section';
  }

  @override
  String localEventsCallTooltip(String name) {
    return 'Llamar a $name';
  }

  @override
  String localEventsDirectionsTooltip(String name) {
    return 'Indicaciones para $name';
  }

  @override
  String get remindersRelativeToday => 'Hoy';

  @override
  String get remindersRelativeTomorrow => 'mañana';

  @override
  String get remindersRelativeYesterday => 'ayer';

  @override
  String remindersRelativeInDays(int days) {
    return 'en $days días';
  }

  @override
  String remindersRelativeDaysAgo(int days) {
    return 'hace $days días';
  }

  @override
  String get remindersKindEvent => 'Evento';

  @override
  String remindersKindRecurring(String interval, String end) {
    return 'Recurrente · $interval$end';
  }

  @override
  String remindersCourseStarts(String day) {
    return 'Empieza $day';
  }

  @override
  String get remindersCourseCompleted => 'Completado';

  @override
  String remindersCourseDayOf(int day, int total) {
    return 'Día $day de $total';
  }

  @override
  String remindersKindCourse(int days) {
    return 'Tratamiento · $days días';
  }

  @override
  String remindersKindCourseWithTimes(int days, String times) {
    return 'Tratamiento · $days días · $times';
  }

  @override
  String remindersIntervalEveryDays(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: '$value días',
      one: '1 día',
    );
    return 'cada $_temp0';
  }

  @override
  String remindersIntervalEveryMonths(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: '$value meses',
      one: '1 mes',
    );
    return 'cada $_temp0';
  }

  @override
  String remindersEndAfterTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veces',
      one: '1 vez',
    );
    return ' · durante $_temp0';
  }

  @override
  String remindersEndUntilDate(String date) {
    return ' · hasta el $date';
  }

  @override
  String get remindersMenuTooltip => 'Opciones del recordatorio';

  @override
  String get remindersMenuMarkDone => 'Marcar como hecho';

  @override
  String get remindersDeleteConfirmTitle => '¿Eliminar este recordatorio?';

  @override
  String remindersDeleteConfirmBody(String title) {
    return '\"$title\" se eliminará definitivamente.';
  }

  @override
  String get remindersErrorPetNotSynced =>
      'El perfil de la mascota no está sincronizado con el servidor. Resuélvelo antes de crear recordatorios.';

  @override
  String get remindersErrorSaveFailed =>
      'No se pudo guardar el recordatorio. Inténtalo de nuevo.';

  @override
  String get remindersErrorDeleteFailed =>
      'No pude eliminar el recordatorio. Inténtalo de nuevo.';

  @override
  String get petNewsTitle => 'Noticias';

  @override
  String get petNewsLoading => 'Cargando noticias...';

  @override
  String get petNewsEmpty =>
      'No hay noticias disponibles para esta categoría ahora.';

  @override
  String get petNewsCategoryAll => 'Todos';

  @override
  String get petNewsCategoryDog => 'Perro';

  @override
  String get petNewsCategoryCat => 'Gato';

  @override
  String get petNewsCategorySmallMammals => 'Pequeños mamíferos';

  @override
  String get petNewsCategoryBird => 'Ave';

  @override
  String get petNewsCategoryReptiles => 'Reptiles y anfibios';

  @override
  String get petNewsCategoryFish => 'Pez';

  @override
  String get petNewsCategoryOther => 'Otro';

  @override
  String get petNewsCategoryGeneral => 'General';

  @override
  String get profileLogoutDialogTitle => 'Cerrar sesión';

  @override
  String get profileLogoutDialogBody =>
      '¿Quieres cerrar la sesión de esta cuenta?';

  @override
  String get profileGuestName => 'Invitado';

  @override
  String get profileNoActiveSession => 'No hay una sesión activa';

  @override
  String profileSummaryBody(String pets) {
    return 'Perfil del propietario vinculado a $pets y listo para la app web adaptable.';
  }

  @override
  String profilePetCount(int count) {
    return '$count mascotas';
  }

  @override
  String get profileContactsTitle => 'Contactos';

  @override
  String get profileEmailLabel => 'Correo electrónico';

  @override
  String get profilePhoneLabel => 'Teléfono';

  @override
  String get profilePhoneNotSet => 'No especificado';

  @override
  String get profileCityLabel => 'Ciudad';

  @override
  String get profileCityNotSet => 'No especificada';

  @override
  String get profileEveningThemeTitle => 'Tema nocturno';

  @override
  String get profileEveningThemeBody =>
      'Vista previa de una paleta más suave para la noche.';

  @override
  String get profileAccountStatusTitle => 'Estado de la cuenta';

  @override
  String get profileSessionLabel => 'Sesión';

  @override
  String get profileSessionActive => 'Activa';

  @override
  String get profilePrivacyLabel => 'Privacidad';

  @override
  String get profilePrivacyUpdated => 'Actualizada';

  @override
  String get profileSupportLabel => 'Asistencia';

  @override
  String get profileSupportAvailable => 'Disponible';

  @override
  String get profileSettingsButton => 'Ajustes';

  @override
  String get profileLogoutButton => 'Cerrar sesión';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileIntro =>
      'Datos del propietario, preferencias y detalles de cuenta en un solo lugar para la app web adaptable.';

  @override
  String get profileRoadmapTitle => 'Próximos pasos';

  @override
  String get profileRoadmapBody =>
      'Aquí podemos ampliar consentimientos, preferencias y vínculos de cuenta sin cambiar el flujo web.';

  @override
  String get activitiesTitle => 'Actividades';

  @override
  String get activitiesSubtitle =>
      'Todo lo relacionado con la vida con tus mascotas.';

  @override
  String get activitiesNewsSubtitle =>
      'Curiosidades y actualidad sobre animales domésticos.';

  @override
  String get activitiesNearbyTitle => 'Cerca de mí';

  @override
  String get activitiesNearbySubtitle =>
      'Veterinarios, tiendas y parques caninos cerca de ti.';

  @override
  String get activitiesEventsTitle => 'Eventos';

  @override
  String get activitiesEventsSubtitle =>
      'Ferias, exposiciones e iniciativas para animales en toda Italia.';

  @override
  String get activitiesGalleryTitle => 'Galería';

  @override
  String get activitiesGallerySubtitle =>
      'Reúne fotos y recuerdos de tus animales.';

  @override
  String get activitiesMarketplaceTitle => 'Mercadillo de segunda mano';

  @override
  String get activitiesMarketplaceSubtitle =>
      'Compra, vende e intercambia artículos para animales.';

  @override
  String get activitiesPetFriendTitle => 'Pet friend';

  @override
  String get activitiesPetFriendSubtitle =>
      'Encuentros y compañía entre animales y responsables.';

  @override
  String get activitiesComingSoonBadge => 'Próximamente';

  @override
  String get activitiesPetFriendDescription =>
      'Conoce a otros responsables y organiza salidas entre animales con afinidades similares.';

  @override
  String get remindersTitle => 'Recordatorios';

  @override
  String get remindersSubtitle =>
      'Vacunas, tratamientos y visitas que debes controlar.';

  @override
  String get remindersCreateButton => 'Crear';

  @override
  String get remindersLoadingTitle => 'Cargando recordatorios';

  @override
  String get remindersLoadingBody =>
      'Leyendo fechas, repeticiones y notas del responsable.';

  @override
  String get remindersSyncErrorLabel => 'Error de sincronización';

  @override
  String get remindersSyncErrorTitle =>
      'No se pudieron sincronizar los recordatorios.';

  @override
  String get remindersSyncErrorBody =>
      'La fuente de demostración sigue disponible. Reintenta cuando vuelva la conexión.';

  @override
  String get remindersEmptyLabel => 'Sin recordatorios';

  @override
  String get remindersEmptyTitle => 'La lista de recordatorios está vacía.';

  @override
  String get remindersEmptyBody =>
      'Crea el primer recordatorio de vacuna o tratamiento para llevarlo todo al día.';

  @override
  String get remindersNoMatchForFilters =>
      'Ningún recordatorio coincide con estos filtros.';

  @override
  String get remindersFilterAll => 'Todos';

  @override
  String get remindersFilterEvents => 'Eventos';

  @override
  String get remindersFilterCourses => 'Ciclos';

  @override
  String get remindersViewList => 'Lista';

  @override
  String get remindersViewCalendar => 'Calendario';

  @override
  String get remindersNothingThisDay => 'No hay actividades este día.';

  @override
  String get remindersTodayCapitalized => 'Hoy';

  @override
  String get remindersEditTitle => 'Editar recordatorio';

  @override
  String get remindersEditSubtitle =>
      'Actualiza el tipo, la fecha y las notas.';

  @override
  String get remindersDosePickerHelp => 'Hora de la dosis';

  @override
  String get remindersDateRequired => 'Introduce una fecha.';

  @override
  String get remindersDateInvalid => 'Fecha no válida (dd/mm/aaaa).';

  @override
  String get remindersFormKind => 'Tipo';

  @override
  String get remindersFormTitleLabel => 'Título';

  @override
  String get remindersFormTitleHint => 'Ej. Refuerzo de vacuna';

  @override
  String remindersFormTitleHintWithPet(String petName) {
    return 'Ej. Refuerzo de vacuna de $petName';
  }

  @override
  String get remindersTitleRequired => 'Introduce un título.';

  @override
  String get remindersFieldDate => 'Fecha';

  @override
  String get remindersFieldNextDue => 'Próximo vencimiento';

  @override
  String get remindersFieldStartDate => 'Fecha de inicio';

  @override
  String get remindersFieldTime => 'Hora';

  @override
  String get remindersRepeats => 'Se repite';

  @override
  String get remindersCustomNumberHint => 'Número';

  @override
  String get remindersRecurrenceEndLabel => 'Fin de la repetición';

  @override
  String get remindersOccurrenceCountHint => 'Número de veces';

  @override
  String get remindersLastDate => 'Última fecha';

  @override
  String get remindersCourseDuration => 'Duración del ciclo';

  @override
  String get remindersDoseTimes => 'Horarios de las dosis';

  @override
  String get remindersAddDoseTime => 'Añadir horario';

  @override
  String get remindersNoDoseTimesNote =>
      'Sin horarios, recibes un aviso diario a las 9:00.';

  @override
  String get remindersFormNote => 'Nota';

  @override
  String get remindersFormNoteHint => 'Ej. Llevar la cartilla sanitaria';

  @override
  String get remindersKindOptionRecurring => 'Recurrente';

  @override
  String get remindersKindOptionCourse => 'Ciclo';

  @override
  String get remindersDatePlaceholder => 'dd/mm/aaaa';

  @override
  String get remindersPreset7Days => '7 días';

  @override
  String get remindersPreset30Days => '30 días';

  @override
  String get remindersPreset6Months => '6 meses';

  @override
  String get remindersPreset12Months => '12 meses';

  @override
  String get remindersPresetCustom => 'Personalizado';

  @override
  String get remindersEndAlways => 'Siempre';

  @override
  String get remindersEndAfterN => 'Durante N veces';

  @override
  String get remindersEndUntil => 'Hasta una fecha';

  @override
  String get remindersUnitDays => 'Días';

  @override
  String get remindersUnitMonths => 'Meses';

  @override
  String get remindersOneDayLess => 'Un día menos';

  @override
  String remindersDurationRange(int min, int max) {
    return 'De $min a $max días.';
  }

  @override
  String remindersDurationUnit(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return '$_temp0';
  }

  @override
  String get remindersOneDayMore => 'Un día más';

  @override
  String get remindersNotFoundTitle => 'Recordatorio no encontrado';

  @override
  String get remindersNotFoundSubtitle =>
      'Este recordatorio ya no está disponible.';

  @override
  String get remindersNotFoundLabel => 'No encontrado';

  @override
  String get remindersNotFoundPanelTitle =>
      'No hay recordatorios para mostrar.';

  @override
  String get remindersNotFoundBody =>
      'Puede que se haya eliminado o que aún no esté sincronizado.';

  @override
  String get remindersBackToList => 'Volver a la lista';

  @override
  String get remindersDetailTitle => 'Detalle del recordatorio';

  @override
  String get remindersDetailSubtitle => 'Tipo, fecha y nota del recordatorio.';

  @override
  String get remindersNoNote => 'No se han añadido notas.';

  @override
  String get remindersSummaryTitle => 'Resumen del recordatorio';

  @override
  String get remindersSummaryPet => 'Animal';

  @override
  String get remindersSummaryStatus => 'Estado';

  @override
  String get remindersDeleteButton => 'Eliminar recordatorio';

  @override
  String get remindersLoadingLabel => 'Carga';

  @override
  String get remindersWait => 'Espera';

  @override
  String get remindersCreateTitle => 'Crear recordatorio';

  @override
  String remindersCreateTitleForPet(String petName) {
    return 'Nuevo recordatorio para $petName';
  }

  @override
  String get remindersCreateSubtitle =>
      'Elige el tipo, la fecha y los detalles.';

  @override
  String get settingsUnitSystemMetricLabel => 'Métrico';

  @override
  String get settingsUnitSystemUkLabel => 'Reino Unido';

  @override
  String get settingsUnitSystemUsLabel => 'EE. UU.';

  @override
  String get settingsUnitSystemMetricDescription => 'km, kg, °C, litros';

  @override
  String get settingsUnitSystemUkDescription => 'millas, libras, °C, litros';

  @override
  String get settingsUnitSystemUsDescription =>
      'millas, libras, °F, galones de EE. UU.';

  @override
  String settingsVolumeLiters(int liters) {
    return '$liters litros';
  }

  @override
  String get settingsUnitLitersName => 'Litros';

  @override
  String get settingsTextSizeSmall => 'Pequeño';

  @override
  String get settingsTextSizeNormal => 'Normal';

  @override
  String get settingsTextSizeLarge => 'Grande';

  @override
  String get settingsTextSizeExtraLarge => 'Muy grande';

  @override
  String get settingsLocationPickerTitle => 'Elegir en el mapa';

  @override
  String get settingsLocationPickerHint =>
      'Mueve el mapa hasta que el marcador esté en el punto correcto y confirma.';

  @override
  String get settingsLocationPickerConfirm => 'Confirmar este punto';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsNumericDatePattern => 'dd/MM/yyyy';

  @override
  String get settingsGuestInitial => 'I';

  @override
  String get settingsGuestName => 'Invitado';

  @override
  String get settingsNoActiveSession => 'No hay una sesión activa';

  @override
  String get settingsSectionSubscription => 'Suscripción';

  @override
  String get settingsSubscriptionAndPayments => 'Suscripción y pagos';

  @override
  String settingsTrialExpiresOn(String date) {
    return 'Prueba · caduca el $date';
  }

  @override
  String get settingsSectionPushNotifications => 'Notificaciones push';

  @override
  String get settingsNotificationsToggle => 'Notificaciones';

  @override
  String get settingsSectionLayout => 'Diseño';

  @override
  String get settingsLayoutWeeksTitle => 'Semanas mostradas en Inicio';

  @override
  String get settingsLayoutWeeksSubtitle =>
      'Cuántas semanas mostrar en el calendario de Inicio.';

  @override
  String get settingsLayoutWeekStartTitle => 'Inicio de la semana';

  @override
  String get settingsLayoutChatTextSizeTitle => 'Tamaño del texto del chat';

  @override
  String get settingsLayoutChatTextSizePreview =>
      'Así se verán los mensajes del chat.';

  @override
  String get settingsLayoutUnitsTitle => 'Unidad de medida';

  @override
  String get settingsSectionPhotosVideos => 'Fotos y vídeos';

  @override
  String get settingsGallerySaveTitle => 'Guardar fotos en la galería';

  @override
  String get settingsGallerySaveSubtitle =>
      'Las fotos y vídeos hechos con la cámara de la app se copian al álbum «VetApp» del teléfono.';

  @override
  String get settingsSectionLocation => 'Ubicación';

  @override
  String get settingsLocationIntro =>
      'Se usa para personalizar eventos y noticias de tu zona.';

  @override
  String get settingsLocationReferenceTitle => 'Ubicación de referencia';

  @override
  String get settingsLocationModeCurrent => 'Actual';

  @override
  String get settingsLocationModeHome => 'Residencia';

  @override
  String get settingsLocationCurrentTitle => 'Ubicación actual';

  @override
  String get settingsLocationDetecting => 'Detectando ubicación…';

  @override
  String get settingsLocationCurrentNotSet => 'Aún no configurada';

  @override
  String get settingsLocationRefresh => 'Actualizar';

  @override
  String get settingsLocationHomeTitle => 'Residencia habitual';

  @override
  String get settingsLocationHomeNotSet => 'No configurada';

  @override
  String get settingsLocationSet => 'Configurar';

  @override
  String get settingsLocationErrorPermissionDenied =>
      'Permiso de ubicación denegado. Actívalo en los ajustes del dispositivo para usar la ubicación actual.';

  @override
  String get settingsLocationErrorServiceDisabled =>
      'La ubicación está desactivada en este dispositivo.';

  @override
  String get settingsLocationErrorTimeout =>
      'No se pudo detectar la ubicación a tiempo. Inténtalo de nuevo.';

  @override
  String get settingsLocationErrorUnsupported =>
      'La ubicación no está disponible en este dispositivo o navegador.';

  @override
  String get settingsSectionPermissions => 'Permisos y consentimientos';

  @override
  String get settingsConsentsUnavailable => 'No disponibles por el momento';

  @override
  String get settingsConsentsTapToRetry => 'Toca para volver a intentarlo';

  @override
  String get settingsConsentTerms => 'Términos del servicio';

  @override
  String get settingsConsentPrivacy => 'Política de privacidad';

  @override
  String get settingsConsentMarketingEmail => 'Correos de marketing';

  @override
  String get settingsConsentAnalytics => 'Análisis de uso';

  @override
  String settingsConsentAccepted(String version, String date) {
    return 'Aceptados v$version el $date';
  }

  @override
  String get settingsConsentToConfirm => 'Pendiente de confirmar';

  @override
  String get settingsClinicalConsentSection => 'Historial clínico y asistente';

  @override
  String get settingsPrivacyPolicyFullTitle =>
      'Política de privacidad completa';

  @override
  String get settingsPrivacyPolicyFullSubtitle =>
      'Lee, descarga o comparte el texto';

  @override
  String get settingsSectionSupport => 'Asistencia';

  @override
  String get settingsHelpCenterTitle => 'Centro de ayuda';

  @override
  String get settingsHelpCenterComingSoon =>
      'Preguntas frecuentes y guías rápidas, próximamente disponibles aquí.';

  @override
  String get settingsContactUs => 'Contáctanos';

  @override
  String get settingsContactUnavailable =>
      'El contacto de asistencia no está disponible en este momento. Inténtalo más tarde.';

  @override
  String settingsContactWriteTo(String email) {
    return 'Escribe a $email para cualquier consulta.';
  }

  @override
  String get settingsRateApp => 'Valora la app';

  @override
  String get settingsRateAppThanks => '¡Gracias por tu apoyo! ⭐';

  @override
  String get settingsSectionInfo => 'Información';

  @override
  String get settingsDataSourcesTitle => 'Fuentes de datos';

  @override
  String get settingsDataSourcesSubtitle =>
      'De dónde procede la información de los lugares del radar';

  @override
  String get settingsAppVersion => 'Versión de la app';

  @override
  String get settingsSectionAccount => 'Cuenta';

  @override
  String get settingsLogout => 'Cerrar sesión';

  @override
  String get settingsLogoutConfirmBody =>
      '¿Quieres cerrar la sesión de esta cuenta?';

  @override
  String get settingsHomeCountryDefault => 'Italia';

  @override
  String get settingsHomeAddressNotFound =>
      'No se encuentra esta dirección. Comprueba los datos e inténtalo de nuevo.';

  @override
  String get settingsHomeAddressOrType => 'O escribe la dirección:';

  @override
  String get settingsHomeAddressStreet => 'Dirección';

  @override
  String get settingsHomeAddressStreetRequired => 'Introduce la dirección';

  @override
  String get settingsHomeAddressPostalCode => 'Código postal';

  @override
  String get settingsHomeAddressPostalCodeRequired =>
      'Introduce el código postal';

  @override
  String get settingsHomeAddressCity => 'Ciudad';

  @override
  String get settingsHomeAddressCityRequired => 'Introduce la ciudad';

  @override
  String get settingsHomeAddressCountry => 'País';

  @override
  String get settingsHomeAddressCountryRequired => 'Introduce el país';

  @override
  String get settingsHomeAddressSearching => 'Buscando…';

  @override
  String get notificationsCategoryReminders => 'Visitas y vacunas';

  @override
  String get notificationsCategoryMedicines => 'Horarios de medicación';

  @override
  String get notificationsCategoryBirthdays => 'Cumpleaños';

  @override
  String get notificationsChannelRemindersName => 'Recordatorios';

  @override
  String get notificationsChannelRemindersDescription =>
      'Visitas, vacunas y otros recordatorios';

  @override
  String get notificationsChannelMedicinesName => 'Medicamentos';

  @override
  String get notificationsChannelBirthdaysDescription =>
      'Cumpleaños de las mascotas';

  @override
  String notificationsReminderTodayBody(String petName, String time) {
    return '$petName · hoy a las $time';
  }

  @override
  String notificationsReminderTomorrowTitle(String title) {
    return 'Mañana: $title';
  }

  @override
  String notificationsReminderTomorrowBody(String petName, String time) {
    return '$petName · a las $time';
  }

  @override
  String notificationsMedicineTitle(String petName) {
    return 'Medicamento para $petName';
  }

  @override
  String notificationsMedicineDayBody(String title, int day, int total) {
    return '$title · día $day de $total';
  }

  @override
  String notificationsMedicineDoseBody(String title, String time) {
    return '$title · dosis de las $time';
  }

  @override
  String notificationsBirthdayTitle(String petName) {
    return '¡Feliz cumpleaños, $petName!';
  }

  @override
  String notificationsBirthdayBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hoy cumple $count años.',
      one: 'Hoy cumple 1 año.',
    );
    return '$_temp0';
  }

  @override
  String get notificationsBirthdayUpcomingTitle => 'Cumpleaños próximo';

  @override
  String notificationsBirthdayUpcomingBody(String petName) {
    return 'En una semana es el cumpleaños de $petName: piensa en un regalo.';
  }

  @override
  String walksPageTitle(String petName) {
    return 'Paseo con $petName';
  }

  @override
  String get walksStatusInProgress => 'Paseo en curso';

  @override
  String get walksStatusPaused => 'Paseo en pausa';

  @override
  String get walksStatDistance => 'Distancia';

  @override
  String get walksStatDuration => 'Duración';

  @override
  String get walksStatPhotos => 'Fotos';

  @override
  String walksStatPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pausas',
      one: 'Pausa',
    );
    return '$_temp0';
  }

  @override
  String get walksActionPause => 'Pausa';

  @override
  String get walksActionResume => 'Reanudar';

  @override
  String get walksActionFinish => 'Finalizar';

  @override
  String get walksActionSaving => 'Guardando…';

  @override
  String get walksActionStarting => 'Iniciando…';

  @override
  String get walksActionStart => 'Iniciar paseo';

  @override
  String get walksWaitingForGps => 'Esperando una señal GPS precisa…';

  @override
  String get walksCameraTooltip => 'Foto o vídeo';

  @override
  String get walksCaptureTakePhoto => 'Hacer foto';

  @override
  String get walksCaptureRecordVideo => 'Grabar vídeo';

  @override
  String walksCaptureVideoLimit(int seconds) {
    return 'Hasta $seconds segundos';
  }

  @override
  String get walksErrorOtherPetActive =>
      'Ya hay un paseo con otra mascota en curso. Termínalo antes de iniciar otro.';

  @override
  String get walksErrorLocationUnavailable =>
      'No puedo detectar tu ubicación, necesaria para registrar el recorrido. Comprueba los permisos e inténtalo de nuevo.';

  @override
  String get walksPhotoPinSemantics => 'Foto tomada durante el paseo';

  @override
  String walksPhotoCaption(String date) {
    return 'Paseo del $date';
  }

  @override
  String get walksMapUnavailable => 'Ruta no disponible';

  @override
  String get walksNoMoveTitle => 'Paseo sin desplazamiento';

  @override
  String get walksNoMoveBody =>
      'No se registró desplazamiento, por lo que el paseo no se guardó.';

  @override
  String get walksNoMoveAck => 'Entendido';

  @override
  String get walksFavoritePromptTitle => '¿Guardar como favorito?';

  @override
  String walksFavoritePromptBody(String distance) {
    return '¿Añadir este paseo ($distance) a tus favoritos ⭐?';
  }

  @override
  String get walksFavoriteNoThanks => 'No, gracias';

  @override
  String get walksFavoriteSave => 'Guardar ⭐';

  @override
  String get walksFavoriteEvictTitle => 'Ya tienes 5 favoritos';

  @override
  String get walksFavoriteEvictBody =>
      'Elige qué favorito eliminar para guardar el paseo recién terminado.';

  @override
  String get walksSheetOpen => 'Abrir paseo';

  @override
  String get walksSheetFinish => 'Finalizar paseo';

  @override
  String walksConfirmFinishTitle(String petName) {
    return '¿Terminar el paseo con $petName?';
  }

  @override
  String get walksConfirmFinishBody =>
      'Se guardará el recorrido registrado hasta ahora.';

  @override
  String get walksSavingSnackbar => 'Guardando paseo…';

  @override
  String get walksNotifPermTitle => 'Ver el paseo en las notificaciones';

  @override
  String get walksNotifPermBody =>
      'Durante el paseo, VetApp muestra una notificación fija con tiempo y distancia. Desde ella puedes pausar o terminar incluso con el teléfono en el bolsillo. Se necesita permiso de notificaciones para verla.\n\nEl paseo se registra aunque elijas «Ahora no».';

  @override
  String get walksNotifPermNotNow => 'Ahora no';

  @override
  String get walksNotifPermAllow => 'Permitir';

  @override
  String walksNotifTitleWithPet(String petName) {
    return 'Paseo con $petName';
  }

  @override
  String walksNotifTitleWithPetPaused(String petName) {
    return 'Paseo con $petName · en pausa';
  }

  @override
  String get walksNotifTitleNoPetPaused => 'Paseo en curso · en pausa';

  @override
  String walksNotifRunningText(String distance) {
    return '$distance recorridos';
  }

  @override
  String get walksNotifFallbackPausedText =>
      'El seguimiento está en pausa. Reanúdalo en la app cuando quieras.';

  @override
  String get walksNotifFallbackRunningText =>
      'VetApp está registrando el recorrido del paseo.';

  @override
  String get walksNotifChannelName => 'Seguimiento del paseo';

  @override
  String get walksSyncFailed =>
      'Sincronización fallida: cambio guardado solo en este teléfono';

  @override
  String get walksFavoriteSaveFailed =>
      'No pude guardar el favorito. Inténtalo de nuevo.';

  @override
  String get walksFavoriteRemoveFailed =>
      'No pude quitar el favorito. Inténtalo de nuevo.';

  @override
  String get walksDeleteFailed =>
      'No pude eliminar el paseo. Inténtalo de nuevo.';

  @override
  String get walksHighlightLongest => 'Más largo';

  @override
  String get walksHighlightMostDurable => 'Mayor duración';

  @override
  String get walksHighlightFavorite => 'Favorito';

  @override
  String walksDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String walksDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get walksBadgeLabelFirstWalk => 'Primer paseo 🐾';

  @override
  String walksBadgeLabelDistance(String km) {
    return '$km km recorridos 🏃';
  }

  @override
  String walksBadgeLabelWalkCount(String count) {
    return '$count paseos 🎖️';
  }

  @override
  String get walksBadgeLabel30Min => '30 minutos en un paseo ⏱️';

  @override
  String get walksBadgeLabel1Hour => 'Una hora en un paseo ⏱️';

  @override
  String get walksBadgeLabelStreak => '7 días seguidos 🔥';

  @override
  String get walksBadgeLabelDawn => 'Paseo al amanecer 🌅';

  @override
  String get walksBadgeLabelNight => 'Paseo nocturno 🌙';

  @override
  String get walksBadgeEarnedBarrier => 'Insignia desbloqueada';

  @override
  String walksBadgeEarnedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¡Nuevas insignias desbloqueadas!',
      one: '¡Nueva insignia desbloqueada!',
    );
    return '$_temp0';
  }

  @override
  String get walksBadgeEarnedAction => '¡Genial!';

  @override
  String get walksBadgeGalleryTitle => 'Insignias';

  @override
  String get walksBadgeNameFirstWalk => 'Primer paseo';

  @override
  String get walksBadgeDescFirstWalk =>
      'Completa tu primer paseo con esta mascota.';

  @override
  String walksBadgeNameKm(String km) {
    return '$km km';
  }

  @override
  String walksBadgeDescKm(String km) {
    return 'Recorre $km km en total.';
  }

  @override
  String get walksBadgeName30Min => '30 minutos';

  @override
  String get walksBadgeDesc30Min => 'Haz un paseo de al menos 30 minutos.';

  @override
  String get walksBadgeName1Hour => 'Una hora';

  @override
  String get walksBadgeDesc1Hour => 'Haz un paseo de al menos una hora.';

  @override
  String get walksBadgeNameStreak => '7 días seguidos';

  @override
  String get walksBadgeDescStreak =>
      'Sal a pasear durante 7 días consecutivos.';

  @override
  String get walksBadgeNameDawn => 'Paseo al amanecer';

  @override
  String get walksBadgeDescDawn =>
      'Haz un paseo entre las 5 y las 7 de la mañana.';

  @override
  String get walksBadgeNameNight => 'Paseo nocturno';

  @override
  String get walksBadgeDescNight =>
      'Haz un paseo después de las 21 o antes de las 5.';

  @override
  String walksBadgeNameWalkCount(String count) {
    return '$count paseos';
  }

  @override
  String walksBadgeDescWalkCount(String count) {
    return 'Completa $count paseos en total.';
  }

  @override
  String get settingsAccountProfile => 'Tu perfil';

  @override
  String get settingsAccountChangeEmail => 'Cambiar correo';

  @override
  String get settingsAccountChangePassword => 'Cambiar contraseña';

  @override
  String get settingsAccountSupport => 'Asistencia';

  @override
  String get settingsAccountSupportSubtitle => 'Escríbenos un correo';

  @override
  String get settingsAccountDelete => 'Eliminar cuenta';

  @override
  String get settingsAccountDeleteSubtitle =>
      'Borra tu cuenta y todos tus datos';

  @override
  String accountSupportSubject(String version) {
    return 'Asistencia VetApp (versión $version)';
  }

  @override
  String accountSupportBody(String version) {
    return 'Escribe aquí tu mensaje:\n\n\n\n—\nVersión de la app: $version';
  }

  @override
  String get accountProfileTitle => 'Tu perfil';

  @override
  String get accountProfileFirstName => 'Nombre';

  @override
  String get accountProfileLastName => 'Apellidos';

  @override
  String get accountProfilePhone => 'Teléfono (opcional)';

  @override
  String get accountProfilePhoneHint => '+34 612 345 678';

  @override
  String get accountProfileFirstNameRequired => 'Introduce tu nombre.';

  @override
  String get accountProfileLastNameRequired => 'Introduce tus apellidos.';

  @override
  String get accountProfilePhoneInvalid => 'Número de teléfono no válido.';

  @override
  String get accountProfilePhotoAdd => 'Añadir foto';

  @override
  String get accountProfilePhotoChange => 'Cambiar foto';

  @override
  String get accountProfilePhotoRemove => 'Quitar foto';

  @override
  String get accountProfilePhotoFailed =>
      'No pude subir la foto. Inténtalo de nuevo.';

  @override
  String get accountProfileSaved => 'Perfil guardado.';

  @override
  String get accountProfileEmailLabel => 'Correo electrónico';

  @override
  String get accountProfileEmailChange => 'Cambiar';

  @override
  String get accountEmailTitle => 'Cambiar correo';

  @override
  String get accountEmailCurrent => 'Correo actual';

  @override
  String get accountEmailNew => 'Nuevo correo';

  @override
  String get accountEmailSame => 'Es tu correo actual.';

  @override
  String get accountEmailSubmit => 'Cambiar correo';

  @override
  String accountEmailApplied(String email) {
    return 'Correo actualizado: a partir de ahora inicias sesión con $email.';
  }

  @override
  String accountEmailConfirmationSent(String email) {
    return 'Te hemos enviado un enlace de confirmación a la nueva dirección ($email). Ábrelo para completar el cambio: hasta entonces seguirás iniciando sesión con el correo actual.';
  }

  @override
  String get accountPasswordTitle => 'Cambiar contraseña';

  @override
  String get accountPasswordCurrent => 'Contraseña actual';

  @override
  String get accountPasswordCurrentRequired =>
      'Introduce la contraseña actual.';

  @override
  String get accountPasswordCurrentWrong =>
      'La contraseña actual no es correcta.';

  @override
  String get accountPasswordNew => 'Nueva contraseña';

  @override
  String get accountPasswordRepeat => 'Repite la nueva contraseña';

  @override
  String get accountPasswordSameAsOld =>
      'La nueva contraseña debe ser distinta de la actual.';

  @override
  String get accountPasswordSubmit => 'Cambiar contraseña';

  @override
  String get accountPasswordChanged => 'Contraseña cambiada.';

  @override
  String get accountDeleteTitle => 'Eliminar cuenta';

  @override
  String get accountDeleteWarningTitle => 'Esta acción es definitiva';

  @override
  String get accountDeleteWarningBody =>
      'Se borrarán para siempre: los perfiles de tus animales, los chats con el asistente, los recordatorios, los paseos, las fotos y los vídeos, los informes y los documentos subidos, las mediciones, los consentimientos, la ubicación guardada y los anuncios que has publicado en el mercadillo. No podremos recuperarlos.';

  @override
  String get accountDeletePasswordLabel =>
      'Escribe tu contraseña para confirmar';

  @override
  String get accountDeletePasswordRequired => 'Introduce tu contraseña.';

  @override
  String get accountDeleteUnderstood =>
      'Lo entiendo: mi cuenta y todos mis datos se borrarán para siempre.';

  @override
  String get accountDeleteSubmit => 'Eliminar mi cuenta definitivamente';

  @override
  String get accountDeleteFailed =>
      'No pude eliminar la cuenta. Inténtalo de nuevo en unos instantes; si el problema continúa, escribe a asistencia.';

  @override
  String get accountDeleteDone => 'Tu cuenta se ha eliminado.';

  @override
  String get accountDeleteReauth =>
      'Por seguridad hace falta una confirmación reciente: vuelve a escribir la contraseña e inténtalo de nuevo.';

  @override
  String get petsValueSexUnknownShort => 'No lo sé';

  @override
  String get petsValueActivitySedentary => 'Sedentario';

  @override
  String get petsValueActivityNormal => 'Normal';

  @override
  String get petsValueActivityActive => 'Activo';

  @override
  String get petsFormSterilized => 'Esterilizado / castrado';

  @override
  String get petsFormMicrochipLabel => 'N.º de microchip';

  @override
  String get petsFormMicrochipHint => '15 dígitos';

  @override
  String get petsFormMicrochipInvalid => 'El microchip tiene 15 dígitos.';

  @override
  String get petsFormCoatColorLabel => 'Color del pelaje';

  @override
  String get petsFormCoatColorHint => 'Ej. negro, marrón';

  @override
  String get petsFormColorLabel => 'Color';

  @override
  String get petsFormColorHint => 'Ej. verde, amarillo';

  @override
  String get petsFormBodyConditionLabel => 'Condición corporal';

  @override
  String get petsFormBodyConditionHint => 'Selecciona la condición corporal';

  @override
  String get petsFormActivityLabel => 'Actividad';

  @override
  String get petsFormActivityHint => 'Selecciona la actividad';

  @override
  String get petsFormDogSizeLabelShort => 'Tamaño';

  @override
  String get petsWizardNext => 'Siguiente';

  @override
  String get petsWizardConfirm => 'Confirmar';

  @override
  String get petsWizardBack => 'Atrás';

  @override
  String petsWizardStepSemantics(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get petsWizardStep1Title => '¿Qué animal es?';

  @override
  String get petsWizardStep1Subtitle =>
      'Elige el tipo de animal y su raza o especie';

  @override
  String get petsWizardStep2Title => 'Cuéntanos sobre tu animal';

  @override
  String get petsWizardStep2Subtitle => '¿Cómo se llama?';

  @override
  String get petsWizardStep3Title => 'Información general';

  @override
  String get petsWizardStep3Subtitle => 'Cuéntanos algo más sobre tu animal';

  @override
  String get petsWizardStep4Title => 'Información final';

  @override
  String get petsWizardStep4Subtitle => '¡Ya casi hemos terminado!';

  @override
  String get petsWizardPureBred => 'De raza';

  @override
  String get petsWizardMixedBreed => 'Mestizo';

  @override
  String get petsWizardDoneTitle => '¡Perfil creado!';

  @override
  String petsWizardDoneMessage(String name) {
    return 'Enhorabuena, $name se ha añadido a tus animales.';
  }

  @override
  String get petsWizardAddAnother => 'Añadir otro animal';

  @override
  String get petsWizardFinish => 'Finalizar';

  @override
  String get petsDataTitle => 'Datos del animal';

  @override
  String get petsDataSectionIdentity => 'Identificación';

  @override
  String get petsDataSectionPhysical => 'Características físicas';

  @override
  String get petsDataSectionDocuments => 'Documentos';

  @override
  String get petsDataNotProvided => 'No indicado';

  @override
  String get petsDataMicrochipMissing => 'Falta';

  @override
  String get petsDataMicrochipMissingDogHint =>
      'En los perros el microchip es obligatorio.';

  @override
  String get petsDataAddMicrochip => 'Añadir microchip';

  @override
  String get petsDataWeightLabel => 'Peso';

  @override
  String get petsDataSummarySterilized => 'esterilizado';

  @override
  String get monitoringTitle => 'Seguimiento';

  @override
  String get petsDetailTabMonitoring => 'Seguimiento';

  @override
  String get monitoringBcsGuideTitle => 'Valora la condición corporal';

  @override
  String monitoringBcsGuideIntro(String petName) {
    return 'El peso por sí solo no basta para saber si un animal está delgado o con sobrepeso: hay que tocarlo y observarlo. Sigue los tres pasos y elige la descripción que más se parezca a $petName.';
  }

  @override
  String get monitoringBcsStepTouch => 'Toca las costillas';

  @override
  String get monitoringBcsStepAbove => 'Mira desde arriba';

  @override
  String get monitoringBcsStepSide => 'Mira de lado';

  @override
  String get monitoringBcsViewAbove => 'Desde arriba';

  @override
  String get monitoringBcsViewSide => 'De lado';

  @override
  String get monitoringBcsRowTouch => 'Al tacto';

  @override
  String get monitoringBcsRowAbove => 'Desde arriba';

  @override
  String get monitoringBcsRowSide => 'De lado';

  @override
  String monitoringBcsGuideScale(String range, String max) {
    return 'En la escala de la fuente: $range de $max';
  }

  @override
  String monitoringBcsGuideChoose(String level) {
    return 'Elegir: $level';
  }

  @override
  String get monitoringBcsGuideClear => 'Quitar la valoración';

  @override
  String get monitoringBcsGuideDisclaimer =>
      'Es una indicación orientativa que no sustituye la consulta con el veterinario. Las ilustraciones son esquemáticas y originales de VetApp.';

  @override
  String monitoringBcsGuideSource(String source) {
    return 'Fuente: $source';
  }

  @override
  String get monitoringBcsGuideTipFurry =>
      'En perros y gatos de pelo largo o denso la vista engaña: toca siempre las costillas. Por ejemplo, un perro peludo puede parecer rellenito aunque debajo esté delgado, mientras que un cachorro o un perro muy musculoso puede parecer «demasiado en forma» y tener un peso correcto.';

  @override
  String get monitoringBcsGuideTipRabbit =>
      'En los conejos el pelo esconde los huesos: toca siempre el lomo, las costillas y la cadera; la vista sola no basta. Un pelaje denso puede hacer que un conejo normal parezca gordo, o que uno delgado parezca normal.';

  @override
  String get monitoringBcsGuideAdviceTitle => 'Consejos';

  @override
  String monitoringBcsGuideAdvice1(String petName) {
    return 'Pesa a $petName cada 2-4 semanas y anota el peso: los cambios lentos se notan más en los números que a simple vista.';
  }

  @override
  String get monitoringBcsGuideAdvice2 =>
      'Valora siempre de la misma manera: mismo lugar, animal de pie y tranquilo, los mismos tres pasos (tacto, vista desde arriba, vista de lado).';

  @override
  String get monitoringBcsGuideAdvice3 =>
      'Si tienes dudas, pregunta al veterinario: la condición corporal se aprende mejor con alguien que te enseñe cómo tocar.';

  @override
  String get monitoringBcsGuideCaveatRabbit =>
      'En los conejos esta escala es menos fiable: dos personas pueden dar puntuaciones distintas al mismo conejo. Si tienes dudas, pregunta al veterinario.';

  @override
  String get monitoringBcsSourceDog =>
      'criterios de la escala de 9 puntos del WSAVA Global Nutrition Committee para perros (Laflamme, 1997), resumidos con palabras nuestras y reducidos a 5 niveles por VetApp. No es material oficial de la WSAVA.';

  @override
  String get monitoringBcsSourceCat =>
      'criterios de la escala de 9 puntos del WSAVA Global Nutrition Committee para gatos (Laflamme, 1997; validada por Bjornvad y colaboradores, 2011), resumidos con palabras nuestras y reducidos a 5 niveles por VetApp. No es material oficial de la WSAVA.';

  @override
  String get monitoringBcsSourceRabbit =>
      'Rabbit Size-O-Meter de 5 niveles de la PFMA (Pet Food Manufacturers\' Association), resumido con palabras nuestras. La fiabilidad entre evaluadores es limitada (Halck y colaboradores, Veterinary Record, 2025).';

  @override
  String get monitoringBcsNotAssessed => 'Sin valorar';

  @override
  String get monitoringBcsAssess => 'Valora la condición corporal';

  @override
  String get monitoringBcsReassess => 'Vuelve a valorar la condición corporal';

  @override
  String get monitoringBcsGuideDog1Touch =>
      'Las costillas, la columna y los huesos de la pelvis se notan enseguida bajo la piel: casi no hay grasa y los músculos parecen reducidos. Un ejemplo: es como tocar los nudillos de una mano cerrada en puño, donde el hueso está justo bajo la piel y no hay nada en medio.';

  @override
  String get monitoringBcsGuideDog1Above =>
      'Cintura muy estrecha y hundida tras las costillas; los huesos de la cadera y del lomo sobresalen. Visto desde arriba, el cuerpo recuerda a un reloj de arena muy delgado.';

  @override
  String get monitoringBcsGuideDog1Side =>
      'Abdomen muy metido hacia dentro; el perfil sube con decisión hacia las patas traseras. Las costillas pueden verse incluso de lejos, sobre todo en perros de pelo corto.';

  @override
  String get monitoringBcsGuideDog2Touch =>
      'Las costillas se notan sin presionar, con muy poca grasa encima, y a veces se ven. Un ejemplo: al pasar la mano por el costado notas cada costilla como un escalón distinto, sin la capa blanda que tiene un perro en forma.';

  @override
  String get monitoringBcsGuideDog2Above =>
      'Cintura bien marcada tras las costillas; los huesos de la pelvis empiezan a notarse. Para encontrarla, mira al perro de pie desde arriba: el cuerpo se estrecha de forma evidente después de la última costilla.';

  @override
  String get monitoringBcsGuideDog2Side =>
      'Abdomen claramente metido hacia dentro. En cachorros en crecimiento y en perros muy atléticos esto puede ser normal: compáralo con lo que notas al tacto en las costillas.';

  @override
  String get monitoringBcsGuideDog3Touch =>
      'Las costillas se notan bien bajo una fina capa de grasa, sin necesidad de presionar. Un ejemplo: es como tocar el dorso de la mano abierta y estirada, donde notas los tendones bajo la piel pero no el hueso afilado.';

  @override
  String get monitoringBcsGuideDog3Above =>
      'Se ve una cintura tras las costillas. Para encontrarla, mira al perro de pie desde arriba: entre el tórax y la pelvis el cuerpo se estrecha ligeramente, sin sobresalir a los lados.';

  @override
  String get monitoringBcsGuideDog3Side =>
      'El vientre sube suavemente desde el pecho hacia las patas traseras. En perros de pelo largo o denso, la silueta se percibe mejor pasando las manos por el cuerpo que mirando.';

  @override
  String get monitoringBcsGuideDog4Touch =>
      'Las costillas se notan con algo de esfuerzo: la capa de grasa es más gruesa, sobre todo en el lomo cerca de la cola. Un ejemplo: es como tocar el dorso de la mano cuando los dedos están cerrados en un puño suave, con más carne sobre los huesos.';

  @override
  String get monitoringBcsGuideDog4Above =>
      'La cintura apenas se intuye o ya no se ve. Desde arriba el cuerpo parece casi rectangular, sin el estrechamiento tras las costillas.';

  @override
  String get monitoringBcsGuideDog4Side =>
      'El abdomen apenas se mete hacia dentro. Cuidado: no confundas el pelo denso con la grasa; toca siempre las costillas antes de decidir.';

  @override
  String get monitoringBcsGuideDog5Touch =>
      'Las costillas no se notan, o solo presionando fuerte, bajo una gruesa capa de grasa que se acumula en el lomo y en la base de la cola. Un ejemplo: es como buscar los huesos en la palma de la mano, donde bajo la piel solo hay una almohadilla blanda y gruesa.';

  @override
  String get monitoringBcsGuideDog5Above =>
      'Sin cintura: el cuerpo es ancho y redondeado, y la barriga puede parecer hinchada. Desde arriba el perro parece más ancho en los costados que en el tórax.';

  @override
  String get monitoringBcsGuideDog5Side =>
      'El abdomen no se mete hacia dentro: la barriga es redonda o cuelga hacia abajo. Un perro así se cansa pronto y le cuesta moverse: háblalo con el veterinario.';

  @override
  String get monitoringBcsGuideCat1Touch =>
      'Las costillas y las vértebras del lomo se notan sin ninguna capa de grasa; en los gatos de pelo corto las costillas se ven. Un ejemplo: es como tocar los nudillos de una mano cerrada en puño, con los huesos justo bajo la piel.';

  @override
  String get monitoringBcsGuideCat1Above =>
      'Cintura muy estrecha tras las costillas. Visto desde arriba, el cuerpo es delgado como un reloj de arena muy estrecho.';

  @override
  String get monitoringBcsGuideCat1Side =>
      'Abdomen muy metido hacia dentro, sin ninguna almohadilla de grasa bajo el vientre. También los músculos a los lados de la columna parecen reducidos.';

  @override
  String get monitoringBcsGuideCat2Touch =>
      'Las costillas se notan fácilmente con muy poca grasa y se aprecian las vértebras del lomo. Un ejemplo: al pasar la mano por el costado notas cada costilla por separado, sin el velo blando que tiene un gato en forma.';

  @override
  String get monitoringBcsGuideCat2Above =>
      'Cintura bien visible tras las costillas. Míralo desde arriba mientras está de pie: el cuerpo se estrecha de forma evidente después de la caja torácica.';

  @override
  String get monitoringBcsGuideCat2Side =>
      'Abdomen algo metido hacia dentro, con poca o ninguna almohadilla de grasa. En los gatos mayores la delgadez puede esconder un problema de salud: si es reciente, pregunta al veterinario.';

  @override
  String get monitoringBcsGuideCat3Touch =>
      'Las costillas se notan con un velo de grasa encima. Un ejemplo: es como tocar el dorso de la mano abierta y estirada, donde notas los tendones bajo la piel pero no el hueso afilado.';

  @override
  String get monitoringBcsGuideCat3Above =>
      'Cuerpo bien proporcionado, con una cintura visible tras las costillas. Desde arriba el gato tiene un ligero reloj de arena, sin sobresalir a los lados.';

  @override
  String get monitoringBcsGuideCat3Side =>
      'El perfil del vientre es suave, con una almohadilla de grasa apenas insinuada. En los gatos de pelo largo la silueta se percibe mejor con las manos que con los ojos.';

  @override
  String get monitoringBcsGuideCat4Touch =>
      'Las costillas son más difíciles de notar: hay que presionar un poco, porque hay más grasa. Un ejemplo: es como tocar el dorso de la mano cuando los dedos están cerrados en un puño suave, con más carne sobre los huesos.';

  @override
  String get monitoringBcsGuideCat4Above =>
      'La cintura se ve poco o no se ve. Desde arriba el cuerpo parece casi rectangular, sin el estrechamiento tras las costillas.';

  @override
  String get monitoringBcsGuideCat4Side =>
      'Barriga redondeada, con una almohadilla de grasa moderada bajo el vientre. Al caminar la almohadilla se balancea ligeramente: en los gatos en forma apenas se insinúa.';

  @override
  String get monitoringBcsGuideCat5Touch =>
      'Las costillas no se notan bajo una gruesa capa de grasa, que se acumula también en el lomo y, en los casos extremos, en la cara y las patas. Un ejemplo: es como buscar los huesos en la palma de la mano, donde solo hay una almohadilla blanda.';

  @override
  String get monitoringBcsGuideCat5Above =>
      'Sin cintura: el cuerpo es ancho. Desde arriba parece más ancho en los costados que en el tórax.';

  @override
  String get monitoringBcsGuideCat5Side =>
      'Barriga redonda o colgante, con una almohadilla de grasa evidente. El gato tiene dificultad para asearse el pelo del lomo y de la parte trasera: háblalo con el veterinario.';

  @override
  String get monitoringBcsGuideRabbit1Touch =>
      'La columna, las costillas y los huesos de la cadera sobresalen y son afilados bajo la piel: no hay grasa y los músculos están reducidos. Un ejemplo: es como tocar los nudillos de una mano cerrada en puño, con el hueso justo bajo la piel.';

  @override
  String get monitoringBcsGuideRabbit1Above =>
      'Lomo y costados hundidos, se notan los huesos de la cadera. Desde arriba el cuerpo parece estrecho y anguloso.';

  @override
  String get monitoringBcsGuideRabbit1Side =>
      'Los cuartos traseros (la grupa) están hundidos, se curvan hacia dentro. Un conejo tan delgado debe verlo pronto el veterinario.';

  @override
  String get monitoringBcsGuideRabbit2Touch =>
      'Las costillas, la columna y la cadera se notan fácilmente, con poca grasa encima. Un ejemplo: al pasar la mano por el lomo notas las vértebras como una fila de pequeños relieves bien distintos.';

  @override
  String get monitoringBcsGuideRabbit2Above =>
      'Costados delgados, con la columna poco cubierta. Desde arriba el cuerpo es más estrecho de lo que esperarías.';

  @override
  String get monitoringBcsGuideRabbit2Side =>
      'Los cuartos traseros son planos. En los conejos de pelo largo el pelo esconde la delgadez: toca siempre el lomo y la cadera.';

  @override
  String get monitoringBcsGuideRabbit3Touch =>
      'Las costillas y la columna se notan con facilidad pero tienen contornos suaves y redondeados, no afilados. Un ejemplo: es como tocar el dorso de la mano abierta y estirada, donde notas los huesos bajo una piel blanda.';

  @override
  String get monitoringBcsGuideRabbit3Above =>
      'Cuerpo bien proporcionado, sin abultamientos en los costados. Desde arriba la silueta es uniforme, del cuello a la cola.';

  @override
  String get monitoringBcsGuideRabbit3Side =>
      'Los cuartos traseros son planos y la barriga no sobresale. El lomo forma una curva regular y no parece ni hundido ni hinchado.';

  @override
  String get monitoringBcsGuideRabbit4Touch =>
      'Para notar las costillas, la columna y la cadera hay que presionar: hay capas de grasa. Un ejemplo: es como tocar el dorso de la mano cuando los dedos están cerrados en un puño suave, con más carne sobre los huesos.';

  @override
  String get monitoringBcsGuideRabbit4Above =>
      'Costados llenos y redondeados. Desde arriba el cuerpo parece más ancho de lo que esperarías.';

  @override
  String get monitoringBcsGuideRabbit4Side =>
      'Los cuartos traseros son redondeados. A menudo se nota también un ligero abultamiento bajo la barbilla (la papada), sobre todo en las hembras.';

  @override
  String get monitoringBcsGuideRabbit5Touch =>
      'La columna y la cadera apenas se notan y las costillas no se notan nada, bajo una gruesa capa de grasa. Un ejemplo: es como buscar los huesos en la palma de la mano, donde solo hay una almohadilla blanda.';

  @override
  String get monitoringBcsGuideRabbit5Above =>
      'Cuerpo ancho y lleno, con los cuartos traseros que sobresalen. Desde arriba la silueta es muy redondeada.';

  @override
  String get monitoringBcsGuideRabbit5Side =>
      'La barriga cuelga y forma una almohadilla de grasa bajo el vientre. Un conejo con tanto peso tiene dificultad para limpiarse y puede tener problemas de piel bajo la cola: pregunta al veterinario.';

  @override
  String get monitoringAddMeasurement => 'Nueva medición';

  @override
  String get monitoringCurrentWeight => 'Peso actual';

  @override
  String monitoringMeasuredOn(String date) {
    return 'Medido el $date';
  }

  @override
  String monitoringChangeSince(String change, String date) {
    return '$change desde el $date';
  }

  @override
  String get monitoringEmptyTitle => 'Aún no hay mediciones';

  @override
  String monitoringEmptyBody(String petName) {
    return 'Registra el peso de $petName para seguir su evolución con el tiempo.';
  }

  @override
  String get monitoringBcsTitle => 'Condición corporal';

  @override
  String monitoringBcsAsOf(String date) {
    return 'Desde la medición del $date';
  }

  @override
  String get monitoringBcsNone =>
      'Toca «Valora la condición corporal» para verla aquí.';

  @override
  String get monitoringBcsVeryThin => 'Muy delgado';

  @override
  String get monitoringBcsThin => 'Delgado';

  @override
  String get monitoringBcsNormal => 'Normal';

  @override
  String get monitoringBcsSlightlyOverweight => 'Ligero sobrepeso';

  @override
  String get monitoringBcsOverweight => 'Sobrepeso';

  @override
  String get monitoringChartTitleWeight => 'Evolución del peso';

  @override
  String get monitoringChartTitleGrowth => 'Curva de crecimiento';

  @override
  String monitoringChartGrowthHint(String petName) {
    return 'El peso de $petName según la edad, sin curvas de referencia: solo sus mediciones.';
  }

  @override
  String get monitoringChartSinglePoint =>
      'Añade otra medición para ver la evolución.';

  @override
  String monitoringChartGrowthHintReference(String petName) {
    return 'El peso de $petName según la edad, comparado con el área de referencia.';
  }

  @override
  String get monitoringGrowthLegend =>
      'Área oscura: del percentil 25 al 75 (la mitad central). Área clara: del 3 al 97. Línea discontinua: mediana.';

  @override
  String monitoringGrowthSourcePuppy(String sizeLabel) {
    return 'Referencia: perros sanos con peso adulto $sizeLabel. Derivado de datos CC BY 4.0 de Salt C. et al., PLOS ONE 2017; no son las curvas oficiales de WALTHAM.';
  }

  @override
  String get monitoringGrowthSourceKitten =>
      'Referencia: gatitos domésticos de pelo corto no esterilizados (EE. UU.). Derivado de datos CC BY 3.0 de Salt C. et al., PLOS ONE 2022; no son las curvas oficiales de WALTHAM.';

  @override
  String monitoringGrowthDisclaimer(String petName) {
    return 'Es una referencia, no un diagnóstico: cada animal crece a su ritmo. Si el peso de $petName sale a menudo del área o cambia de repente, consúltalo con el veterinario.';
  }

  @override
  String monitoringGrowthExpectedAdult(String range) {
    return 'Peso adulto esperado: $range';
  }

  @override
  String get monitoringGrowthChange => 'Cambiar';

  @override
  String get monitoringGrowthPromptTitle => 'Mostrar el área de referencia';

  @override
  String monitoringGrowthPromptBody(String petName) {
    return 'Para comparar a $petName con cachorros sanos hace falta el peso que tendrá de adulto: elige el rango más probable (raza, padres, veterinario).';
  }

  @override
  String get monitoringGrowthPromptButton => 'Elige el peso adulto';

  @override
  String get monitoringGrowthNoReferenceHeavy =>
      'Para los perros de más de 40 kg no hay curvas de referencia fiables: las razas muy grandes crecen de formas muy distintas.';

  @override
  String monitoringGrowthSheetTitle(String petName) {
    return 'Peso adulto esperado de $petName';
  }

  @override
  String monitoringGrowthClassUnder(String max) {
    return 'Menos de $max';
  }

  @override
  String monitoringGrowthClassBetween(String min, String max) {
    return 'De $min a $max';
  }

  @override
  String monitoringGrowthClassOver(String min) {
    return 'Más de $min';
  }

  @override
  String get monitoringGrowthClassUnknown => 'No lo sé: sin área de referencia';

  @override
  String get monitoringAxisAgeMonths => 'Edad (meses)';

  @override
  String monitoringAxisWeight(String unit) {
    return 'Peso ($unit)';
  }

  @override
  String monitoringTooltipAge(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months meses',
      one: '1 mes',
    );
    return '$_temp0';
  }

  @override
  String get monitoringHistoryTitle => 'Historial';

  @override
  String get monitoringDeleteTitle => '¿Eliminar la medición?';

  @override
  String monitoringDeleteMessage(String date) {
    return 'El peso del $date se quitará del historial.';
  }

  @override
  String get monitoringSheetTitleNew => 'Nueva medición';

  @override
  String get monitoringSheetTitleEdit => 'Editar medición';

  @override
  String get monitoringFieldDate => 'Fecha';

  @override
  String get monitoringFieldWeightKg => 'Peso (kg)';

  @override
  String get monitoringFieldWeightLb => 'Peso (lb)';

  @override
  String get monitoringFieldWeightHintKg => 'Ej. 10,5';

  @override
  String get monitoringFieldWeightHintLb => 'Ej. 22,5';

  @override
  String get monitoringFieldNote => 'Nota (opcional)';

  @override
  String get monitoringErrorWeight =>
      'Introduce un peso válido, mayor que cero.';

  @override
  String get monitoringErrorDateFuture =>
      'La fecha no puede estar en el futuro.';

  @override
  String monitoringErrorDateBirth(String petName) {
    return 'La fecha es anterior al nacimiento de $petName.';
  }

  @override
  String get monitoringSaveFailed =>
      'No pude guardar la medición: inténtalo de nuevo.';

  @override
  String get monitoringDeleteFailed =>
      'No pude eliminar la medición: inténtalo de nuevo.';

  @override
  String get monitoringActivityTitle => 'Actividad';

  @override
  String monitoringActivitySubtitle(String petName) {
    return 'Los paseos de $petName en las últimas semanas.';
  }

  @override
  String get monitoringActivityDistance => 'Distancia';

  @override
  String get monitoringActivityTime => 'Tiempo';

  @override
  String get monitoringActivityStatWalks => 'Paseos';

  @override
  String monitoringActivityEmpty(String petName) {
    return 'No hay paseos en los últimos 3 meses. Registra un paseo desde la pestaña Paseos para ver aquí la actividad de $petName.';
  }

  @override
  String monitoringActivityWeekOf(String date) {
    return 'Semana del $date';
  }

  @override
  String monitoringActivityWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paseos',
      one: '1 paseo',
    );
    return '$_temp0';
  }

  @override
  String get medCatVisit => 'Visitas';

  @override
  String get medCatExam => 'Pruebas';

  @override
  String get medCatVaccine => 'Vacunas';

  @override
  String get medCatTherapy => 'Tratamientos';

  @override
  String get medCatDocument => 'Documentos';

  @override
  String get medCatCondition => 'Patologías';

  @override
  String get medCatVisitOne => 'Visita';

  @override
  String get medCatExamOne => 'Prueba';

  @override
  String get medCatVaccineOne => 'Vacuna';

  @override
  String get medCatTherapyOne => 'Tratamiento';

  @override
  String get medCatDocumentOne => 'Documento';

  @override
  String medCatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registrados',
      one: '1 registrado',
    );
    return '$_temp0';
  }

  @override
  String get medSubCheckup => 'Visita de control';

  @override
  String get medSubSpecialist => 'Visita con especialista';

  @override
  String get medSubFirstVisit => 'Primera visita';

  @override
  String get medSubEmergency => 'Urgencia';

  @override
  String get medSubPostSurgery => 'Control posoperatorio';

  @override
  String get medSubBlood => 'Análisis de sangre';

  @override
  String get medSubUrine => 'Análisis de orina';

  @override
  String get medSubStool => 'Análisis de heces';

  @override
  String get medSubXray => 'Radiografía';

  @override
  String get medSubUltrasound => 'Ecografía';

  @override
  String get medSubAntiparasitic => 'Antiparasitario';

  @override
  String get medSubMedication => 'Medicamento';

  @override
  String get medSubOther => 'Otro';

  @override
  String get medAddTitle => '¿Qué quieres añadir?';

  @override
  String get medAddAction => 'Añadir';

  @override
  String get medCatConditionOne => 'Patología';

  @override
  String get medHistoryTitle => 'Historial';

  @override
  String get medHistorySubtitle => 'Todos los eventos registrados, mes a mes.';

  @override
  String get medHistoryEmpty => 'Ningún evento registrado';

  @override
  String get medHistoryPrevMonth => 'Mes anterior';

  @override
  String get medHistoryNextMonth => 'Mes siguiente';

  @override
  String medHistoryDayTitle(String date) {
    return 'Eventos del $date';
  }

  @override
  String get medHistoryDayEmpty => 'Ningún evento este día';

  @override
  String medHistoryDayA11y(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '1 evento',
      zero: 'ningún evento',
    );
    return '$date: $_temp0';
  }

  @override
  String get medHistorySend => 'Enviar historial';

  @override
  String get medHistorySendAll => 'Todo el historial (PDF)';

  @override
  String get medHistorySendAllSubtitle =>
      'Un PDF con todos los eventos por orden de fecha';

  @override
  String get medHistorySendFiles => 'Archivos individuales';

  @override
  String get medHistoryPreparing => 'Preparando el PDF…';

  @override
  String get medHistoryExportFailed =>
      'No pude preparar el PDF. Inténtalo de nuevo.';

  @override
  String get medHistoryConditionsMissing =>
      'No pude leer las patologías: no aparecen en el PDF.';

  @override
  String medPdfTitle(String petName) {
    return 'Historial clínico de $petName';
  }

  @override
  String get medPdfSpeciesBreed => 'Especie y raza';

  @override
  String get medPdfBirthDate => 'Fecha de nacimiento';

  @override
  String get medPdfExportDate => 'Fecha de exportación';

  @override
  String get medPdfColDate => 'Fecha';

  @override
  String get medPdfColCategory => 'Categoría';

  @override
  String get medPdfColTitle => 'Título';

  @override
  String get medPdfColNotes => 'Notas';

  @override
  String get medPdfNoDate => 'Sin fecha';

  @override
  String get medPdfEmpty => 'Ningún evento registrado.';

  @override
  String medPdfPage(int page, int pages) {
    return 'Página $page de $pages';
  }

  @override
  String get medPdfConditionOngoing => 'En curso';

  @override
  String get medPdfConditionResolved => 'Resuelta';

  @override
  String medPdfConditionResolvedOn(String date) {
    return 'Resuelta el $date';
  }

  @override
  String medPdfConditionTherapy(String therapy) {
    return 'Tratamiento: $therapy';
  }

  @override
  String get medNewVisit => 'Nueva visita';

  @override
  String get medNewExam => 'Nueva prueba';

  @override
  String get medNewVaccine => 'Nueva vacuna';

  @override
  String get medNewTherapy => 'Nuevo tratamiento';

  @override
  String get medNewDocument => 'Nuevo documento';

  @override
  String get medNewCondition => 'Nueva patología';

  @override
  String get medEmptyVisitTitle => 'Ninguna visita registrada';

  @override
  String medEmptyVisitBody(String petName) {
    return 'Añade las visitas de $petName para tener en un solo lugar los controles y las indicaciones del veterinario.';
  }

  @override
  String get medEmptyVisitAction => 'Añade la primera visita';

  @override
  String get medEmptyExamTitle => 'Ninguna prueba registrada';

  @override
  String medEmptyExamBody(String petName) {
    return 'Sube las pruebas de $petName, como análisis de sangre o radiografías, para tenerlas siempre a mano.';
  }

  @override
  String get medEmptyExamAction => 'Añade la primera prueba';

  @override
  String get medEmptyVaccineTitle => 'Ninguna vacuna registrada';

  @override
  String medEmptyVaccineBody(String petName) {
    return 'Guarda aquí las vacunas y los refuerzos de $petName, con la fecha de cada administración.';
  }

  @override
  String get medEmptyVaccineAction => 'Añade la primera vacuna';

  @override
  String get medEmptyTherapyTitle => 'Ningún tratamiento registrado';

  @override
  String medEmptyTherapyBody(String petName) {
    return 'Anota los tratamientos de $petName: medicamentos, antiparasitarios y curas en curso o pasadas.';
  }

  @override
  String get medEmptyTherapyAction => 'Añade el primer tratamiento';

  @override
  String get medEmptyDocumentTitle => 'Ningún documento subido';

  @override
  String medEmptyDocumentBody(String petName) {
    return 'Sube informes, certificados y otros documentos de $petName para compartirlos con el veterinario.';
  }

  @override
  String get medEmptyDocumentAction => 'Añade el primer documento';

  @override
  String get medEmptyConditionTitle => 'Ninguna patología registrada';

  @override
  String medEmptyConditionBody(String petName) {
    return 'Anota las enfermedades de $petName, en curso o ya resueltas, con fechas y tratamiento.';
  }

  @override
  String get medEmptyConditionAction => 'Añade la primera patología';

  @override
  String get medFieldTitle => 'Título';

  @override
  String get medFieldCategory => 'Categoría';

  @override
  String get medFieldType => 'Tipo';

  @override
  String get medFieldTypeNone => 'No especificado';

  @override
  String get medFieldEventDate => 'Fecha';

  @override
  String get medFieldNotes => 'Notas';

  @override
  String get medFieldNotesHint => 'Escribe una nota opcional.';

  @override
  String get medFieldFile => 'Archivo adjunto';

  @override
  String get medAttachAdd => 'Añadir archivo';

  @override
  String get medAttachChange => 'Cambiar archivo';

  @override
  String get medEditDetailsTitle => 'Editar detalles';

  @override
  String get medTitleRequired => 'Escribe un título o adjunta un archivo.';

  @override
  String get medDateInvalid => 'Fecha no válida (dd/mm/aaaa).';

  @override
  String get medDatePlaceholder => 'dd/mm/aaaa';

  @override
  String medSuggestHint(String category) {
    return 'Por el título parece: $category. ¿Quieres clasificarlo así?';
  }

  @override
  String get medSuggestApply => 'Sí, clasificar';

  @override
  String medSuggestPill(String category) {
    return 'Quizá: $category';
  }

  @override
  String medActionClassifyAs(String category) {
    return 'Clasificar como $category';
  }

  @override
  String get medActionEditDetails => 'Editar detalles';

  @override
  String get medCondName => 'Nombre de la patología';

  @override
  String get medCondNameRequired => 'Escribe el nombre de la patología.';

  @override
  String get medCondStarted => 'Fecha de inicio';

  @override
  String get medCondStatus => 'Estado';

  @override
  String get medCondOngoing => 'En curso';

  @override
  String get medCondResolved => 'Resuelta';

  @override
  String get medCondEnded => 'Fecha de fin';

  @override
  String get medCondEndBeforeStart =>
      'La fecha de fin es anterior a la de inicio.';

  @override
  String get medCondTherapy => 'Tratamiento';

  @override
  String get medCondTherapyHint => 'Medicamentos, dosis, duración…';

  @override
  String get medCondAttachment => 'Receta o documentos';

  @override
  String medCondSince(String date) {
    return 'Desde el $date';
  }

  @override
  String medCondPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String get medCondSaveFailed =>
      'No pude guardar la patología. Inténtalo de nuevo.';

  @override
  String get medCondDeleteFailed =>
      'No pude eliminar la patología. Inténtalo de nuevo.';

  @override
  String get medCondDeleteTitle => '¿Eliminar esta patología?';

  @override
  String medCondDeleteBody(String name) {
    return '«$name» se eliminará.';
  }

  @override
  String get medCondLoadError =>
      'No puedo leer las patologías. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get medCondUploadFailed =>
      'No pude subir el archivo. Inténtalo de nuevo.';

  @override
  String get medCondOpenFile => 'Abrir adjunto';

  @override
  String get medicalRecordSourceFromReminder => 'Desde un recordatorio';

  @override
  String get reminderCatGrooming => 'Peluquería';

  @override
  String get reminderCatOther => 'Otro';

  @override
  String get remindersFormCategory => 'Categoría';

  @override
  String get remindersFormSubtype => 'Tipo';

  @override
  String get remindersFormSubtypeNone => 'Ninguno';

  @override
  String get remindersDoneTitle => '¿Hecho?';

  @override
  String remindersDoneRecordHint(String pet) {
    return 'Regístralo en el historial de $pet.';
  }

  @override
  String get remindersDonePlainHint => '¿Lo marco como hecho?';

  @override
  String get remindersDoneFieldTitle => 'Título';

  @override
  String get remindersDoneFieldDate => 'Cuándo ocurrió';

  @override
  String get remindersDoneFieldNotes => 'Notas (opcionales)';

  @override
  String get remindersDoneConfirmRecord => 'Sí, registrar';

  @override
  String get remindersDoneConfirmPlain => 'Sí, hecho';

  @override
  String get remindersDonePostpone => 'Posponer';

  @override
  String get remindersDoneNotDone => 'No hecho';

  @override
  String remindersDoneRecorded(String pet) {
    return 'Registrado en el historial de $pet.';
  }

  @override
  String get remindersDoneMarked => 'Marcado como hecho.';

  @override
  String get remindersDoneDismissed => 'Marcado como no hecho.';

  @override
  String get remindersDonePostponed => 'Te lo recordaré mañana.';

  @override
  String get remindersDoneTooltip => 'Marcar como hecho';
}
