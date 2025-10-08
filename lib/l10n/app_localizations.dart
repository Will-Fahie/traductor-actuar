import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('es', ''), // Spanish
    Locale('en', ''), // English
  ];

  // Home Screen
  String get homeTitle => locale.languageCode == 'es' ? 'Herramientas' : 'Tools';
  String get homeSubtitle => locale.languageCode == 'es' 
      ? 'Accede a todas las funciones de la aplicación' 
      : 'Access all application functions';
  String get welcomeTitle => locale.languageCode == 'es' ? 'Shiram Taurme' : 'Shiram Taurme';
  String get welcomeSubtitle => locale.languageCode == 'es' 
      ? 'Explora las herramientas de traducción y recursos educativos.' 
      : 'Explore translation tools and educational resources.';
  String get logoutButton => locale.languageCode == 'es' ? 'Cerrar sesión' : 'Logout';

  // Menu Items
  String get dictionary => locale.languageCode == 'es' ? 'Diccionario' : 'Dictionary';
  String get dictionarySubtitle => locale.languageCode == 'es' ? 'Buscar palabras' : 'Search words';
  String get spanishAchuar => locale.languageCode == 'es' ? 'Español-Achuar' : 'Spanish-Achuar';
  String get translator => locale.languageCode == 'es' ? 'Traductor' : 'Translator';
  String get phraseSubmission => locale.languageCode == 'es' ? 'Envío de Frases' : 'Phrase Submission';
  String get contribute => locale.languageCode == 'es' ? 'Contribuir' : 'Contribute';
  String get teaching => locale.languageCode == 'es' ? 'Enseñanza' : 'Teaching';
  String get educationalResources => locale.languageCode == 'es' ? 'Recursos educativos' : 'Educational resources';
  String get guides => locale.languageCode == 'es' ? 'Guías' : 'Guides';
  String get guideResources => locale.languageCode == 'es' ? 'Recursos de guía' : 'Guide resources';
  String get englishAchuar => locale.languageCode == 'es' ? 'Inglés-Achuar' : 'English-Achuar';
  String get comingSoon => locale.languageCode == 'es' ? 'Próximamente' : 'Coming Soon';

  // Translator Screen
  String get translatorTitle => locale.languageCode == 'es' ? 'Traductor Español-Achuar' : 'Spanish-Achuar Translator';
  String get aboutTranslator => locale.languageCode == 'es' ? 'Acerca del Traductor' : 'About Translator';
  String get translateButton => locale.languageCode == 'es' ? 'Traducir a Inglés' : 'Translate to English';
  String get clearAll => locale.languageCode == 'es' ? 'Limpiar todo' : 'Clear all';
  String get translatorInfo => locale.languageCode == 'es' ? 'Información sobre el traductor' : 'Translator information';
  String get spanishText => locale.languageCode == 'es' ? 'Texto en español' : 'Spanish text';
  String get englishTranslation => locale.languageCode == 'es' ? 'Traducción al inglés' : 'English translation';
  String get achuarTranslation => locale.languageCode == 'es' ? 'Traducción al achuar (opcional)' : 'Achuar translation (optional)';
  String get enterSpanishText => locale.languageCode == 'es' ? 'Ingrese texto en español...' : 'Enter Spanish text...';
  String get enterAchuarText => locale.languageCode == 'es' ? 'Ingrese texto en Achuar...' : 'Enter Achuar text...';
  String get translationWillAppearHere => locale.languageCode == 'es' ? 'La traducción aparecerá aquí...' : 'Translation will appear here...';
  String get recentTranslations => locale.languageCode == 'es' ? 'Traducciones recientes' : 'Recent translations';
  String get lists => locale.languageCode == 'es' ? 'Listas' : 'Lists';
  
  // Translator Dialog
  String get translatorDescription => locale.languageCode == 'es' 
      ? 'Este es un traductor de Español a Inglés que te ayuda a traducir palabras y frases.'
      : 'This is a Spanish to English translator that helps you translate words and phrases.';
  String get howYouHelp => locale.languageCode == 'es' ? '¿Cómo nos ayudas?' : 'How do you help us?';
  String get helpDescription => locale.languageCode == 'es'
      ? 'Al agregar la traducción en Achuar, nos estás proporcionando datos valiosos que nos ayudan a construir un traductor directo de Achuar a Inglés.'
      : 'By adding the Achuar translation, you are providing us with valuable data that helps us build a direct Achuar to English translator.';
  String get contributionMessage => locale.languageCode == 'es'
      ? 'Cada traducción que compartes contribuye a preservar y digitalizar el idioma Achuar. ¡Gracias por tu colaboración!'
      : 'Each translation you share contributes to preserving and digitalizing the Achuar language. Thank you for your collaboration!';
  String get understood => locale.languageCode == 'es' ? 'Entendido' : 'Understood';

  // Welcome Screen
  String get welcome => locale.languageCode == 'es' ? 'Bienvenido' : 'Welcome';
  String get appDescription => locale.languageCode == 'es' 
      ? 'Una aplicación para aprender y traducir el idioma Achuar'
      : 'An application to learn and translate the Achuar language';
  String get getStarted => locale.languageCode == 'es' ? 'Comenzar' : 'Get Started';
  String get enterName => locale.languageCode == 'es' ? 'Ingresa tu nombre' : 'Enter your name';
  String get continueAsGuest => locale.languageCode == 'es' ? 'Continuar como invitado' : 'Continue as guest';
  String get existingUser => locale.languageCode == 'es' ? 'Usuario existente' : 'Existing user';
  String get loginWithAccount => locale.languageCode == 'es' ? 'Ingresa con tu cuenta' : 'Login with your account';
  String get newUser => locale.languageCode == 'es' ? 'Nuevo usuario' : 'New user';
  String get createAccount => locale.languageCode == 'es' ? 'Crea tu cuenta' : 'Create your account';
  String get enterAsGuest => locale.languageCode == 'es' ? 'Entrar como invitado' : 'Enter as guest';
  String get exploreWithoutAccount => locale.languageCode == 'es' ? 'Explora sin cuenta' : 'Explore without account';
  String get selectHowToContinue => locale.languageCode == 'es' ? 'Selecciona cómo deseas continuar' : 'Select how you want to continue';
  String get noInternetConnection => locale.languageCode == 'es' ? 'Sin conexión a internet' : 'No internet connection';
  String get noInternetMessage => locale.languageCode == 'es' ? 'Por favor, conéctese a internet para iniciar sesión o crear una cuenta.' : 'Please connect to the internet to log in or create an account.';
  String get pleaseEnterUsername => locale.languageCode == 'es' ? 'Por favor, ingrese un nombre de usuario.' : 'Please enter a username.';
  String get enterUsername => locale.languageCode == 'es' ? 'Ingrese su nombre de usuario' : 'Enter your username';
  String get enter => locale.languageCode == 'es' ? 'Entrar' : 'Enter';

  // Coming Soon Screen
  String get englishAchuarTranslator => locale.languageCode == 'es' ? 'Traductor Inglés-Achuar' : 'English-Achuar Translator';
  String get workingOnFeature => locale.languageCode == 'es' 
      ? 'Estamos trabajando en un traductor directo de Inglés a Achuar. Esta característica estará disponible próximamente y te permitirá traducir directamente desde el inglés al idioma Achuar sin pasos intermedios.'
      : 'We are working on a direct English to Achuar translator. This feature will be available soon and will allow you to translate directly from English to the Achuar language without intermediate steps.';

  // Guide Resources Screen
  String get guideResourcesTitle => locale.languageCode == 'es' ? 'Recursos de Guía' : 'Guide Resources';
  String get guideResourcesComingSoon => locale.languageCode == 'es' 
      ? 'Esta sección estará disponible próximamente con categorías detalladas de aves y mamíferos.'
      : 'This section will be available soon with detailed categories of birds and mammals.';
  String get birds => locale.languageCode == 'es' ? 'Aves' : 'Birds';
  String get discoverBirdSpecies => locale.languageCode == 'es' ? 'Descubre las especies de aves' : 'Discover bird species';
  String get exploreNativeMammals => locale.languageCode == 'es' ? 'Explora los mamíferos nativos' : 'Explore native mammals';
  String get offlineMode => locale.languageCode == 'es' ? 'Modo sin conexión' : 'Offline mode';
  String get downloadTextImagesAudio => locale.languageCode == 'es' ? 'Descargue el texto, imágenes y audio para uso sin conexión' : 'Download text, images and audio for offline use';
  String get downloadMayTakeMinutes => locale.languageCode == 'es' ? 'La descarga puede tomar varios minutos' : 'Download may take several minutes';
  String get downloaded => locale.languageCode == 'es' ? 'Descargado' : 'Downloaded';

  // Dictionary Screen
  String get searchDictionary => locale.languageCode == 'es' ? 'Buscar en el diccionario' : 'Search dictionary';
  String get searchHint => locale.languageCode == 'es' ? 'Buscar palabras...' : 'Search words...';
  String get noResults => locale.languageCode == 'es' ? 'No se encontraron resultados' : 'No results found';
  String get clearSearch => locale.languageCode == 'es' ? 'Limpiar búsqueda' : 'Clear search';

  // Teaching Resources Screen
  String get teachingResources => locale.languageCode == 'es' ? 'Recursos de Enseñanza' : 'Teaching Resources';
  String get lessonsAndExercises => locale.languageCode == 'es' ? 'Lecciones y ejercicios' : 'Lessons and exercises';
  String get beginner => locale.languageCode == 'es' ? 'Principiante' : 'Beginner';
  String get intermediate => locale.languageCode == 'es' ? 'Intermedio' : 'Intermediate';
  String get advanced => locale.languageCode == 'es' ? 'Avanzado' : 'Advanced';
  String get customLessons => locale.languageCode == 'es' ? 'Lecciones Personalizadas' : 'Custom Lessons';
  String get noCustomLessons => locale.languageCode == 'es' ? 'No tienes lecciones personalizadas' : 'You have no custom lessons';
  String get createFirstLesson => locale.languageCode == 'es' ? 'Crea tu primera lección personalizada' : 'Create your first custom lesson';
  String get newLesson => locale.languageCode == 'es' ? 'Nueva lección' : 'New lesson';
  String get phrases => locale.languageCode == 'es' ? 'frases' : 'phrases';
  String get download => locale.languageCode == 'es' ? 'Descargar' : 'Download';
  String get audioFilesDownloaded => locale.languageCode == 'es' ? 'archivos de audio descargados' : 'audio files downloaded';
  String get errorDownloadingAudio => locale.languageCode == 'es' ? 'Error al descargar audio' : 'Error downloading audio';
  String get createLesson => locale.languageCode == 'es' ? 'Crear lección' : 'Create lesson';
  String get availableResources => locale.languageCode == 'es' ? 'Recursos disponibles' : 'Available Resources';
  String get accessLessonsAndMaterials => locale.languageCode == 'es' ? 'Accede a lecciones y materiales educativos' : 'Access lessons and educational materials';
  String get myLessons => locale.languageCode == 'es' ? 'Mis Lecciones' : 'My Lessons';
  String get createAndManageLessons => locale.languageCode == 'es' ? 'Crea y gestiona tus propias lecciones' : 'Create and manage your own lessons';
  String get lessons => locale.languageCode == 'es' ? 'lecciones' : 'lessons';
  String get loadingResources => locale.languageCode == 'es' ? 'Cargando recursos...' : 'Loading resources...';
  String get noResourcesFound => locale.languageCode == 'es' ? 'No se encontraron recursos' : 'No resources found';

  // Lesson Screen
  String get lesson => locale.languageCode == 'es' ? 'Lección' : 'Lesson';
  String get downloadForOffline => locale.languageCode == 'es' ? 'Descargar para uso sin conexión' : 'Download for offline use';
  String get downloading => locale.languageCode == 'es' ? 'Descargando...' : 'Downloading...';
  String get playAudio => locale.languageCode == 'es' ? 'Reproducir audio' : 'Play audio';
  String get audioNotAvailableOffline => locale.languageCode == 'es' 
      ? 'Audio no disponible sin conexión. Descargue la lección cuando esté en línea para guardar el audio para uso offline.'
      : 'Audio not available offline. Download the lesson when online to save audio for offline use.';
  String get couldNotPlayAudio => locale.languageCode == 'es' 
      ? 'No se pudo reproducir el audio. Redescargue la lección cuando esté en línea para actualizar el audio.'
      : 'Could not play audio. Re-download the lesson when online to update the audio.';

  // Custom Lesson Creation
  String get createCustomLesson => locale.languageCode == 'es' ? 'Crear Lección Personalizada' : 'Create Custom Lesson';
  String get editCustomLesson => locale.languageCode == 'es' ? 'Editar Lección Personalizada' : 'Edit Custom Lesson';
  String get editLesson => locale.languageCode == 'es' ? 'Editar lección' : 'Edit lesson';
  String get createCustomLessonTitle => locale.languageCode == 'es' ? 'Crear lección personalizada' : 'Create custom lesson';
  String get lessonName => locale.languageCode == 'es' ? 'Nombre de la lección' : 'Lesson name';
  String get exampleJungleAnimals => locale.languageCode == 'es' ? 'Ejemplo: Animales de la selva' : 'Example: Jungle animals';
  String get editLessonRedownloadWarning => locale.languageCode == 'es' ? 'Al editar esta lección, será necesario redescargarla para uso offline' : 'When editing this lesson, it will need to be re-downloaded for offline use';
  String get lessonPhrases => locale.languageCode == 'es' ? 'Frases de la lección' : 'Lesson phrases';
  String get phrase => locale.languageCode == 'es' ? 'Frase' : 'Phrase';
  String get enterAchuar => locale.languageCode == 'es' ? 'Introduce Achuar...' : 'Enter Achuar...';
  String get enterSpanish => locale.languageCode == 'es' ? 'Introduce español...' : 'Enter Spanish...';
  String get translationAppearHere => locale.languageCode == 'es' ? 'Traducción aparecerá aquí...' : 'Translation will appear here...';
  String get saveChanges => locale.languageCode == 'es' ? 'Guardar cambios' : 'Save changes';
  String get saveLesson => locale.languageCode == 'es' ? 'Guardar lección' : 'Save lesson';
  String get addTranslation => locale.languageCode == 'es' ? 'Agregar traducción' : 'Add translation';
  String get removeTranslation => locale.languageCode == 'es' ? 'Eliminar traducción' : 'Remove translation';
  String get redownloadRequired => locale.languageCode == 'es' 
      ? 'Será necesario volver a descargar esta lección para usar sin conexión después de guardar los cambios.'
      : 'This lesson will need to be re-downloaded for offline use after saving changes.';

  // Animal Lists
  String get mammals => locale.languageCode == 'es' ? 'Mamíferos' : 'Mammals';
  String get editMode => locale.languageCode == 'es' ? 'Modo de edición' : 'Edit mode';
  String get enterPassword => locale.languageCode == 'es' ? 'Ingrese la contraseña' : 'Enter password';
  String get password => locale.languageCode == 'es' ? 'Contraseña' : 'Password';
  String get confirm => locale.languageCode == 'es' ? 'Confirmar' : 'Confirm';
  String get incorrectPassword => locale.languageCode == 'es' ? 'Contraseña incorrecta' : 'Incorrect password';

  // Phrase Submission
  String get phraseSubmissionTitle => locale.languageCode == 'es' ? 'Envío de Frases' : 'Phrase Submission';
  String get recentContributions => locale.languageCode == 'es' ? 'Contribuciones Recientes' : 'Recent Contributions';
  String get submitPhrase => locale.languageCode == 'es' ? 'Enviar frase' : 'Submit phrase';
  String get spanishPhrase => locale.languageCode == 'es' ? 'Frase en español' : 'Spanish phrase';
  String get achuarPhrase => locale.languageCode == 'es' ? 'Frase en achuar' : 'Achuar phrase';

  // Coming Soon Screen
  String get featureComingSoon => locale.languageCode == 'es' ? 'Función próximamente' : 'Feature coming soon';
  String get stayTuned => locale.languageCode == 'es' ? 'Mantente atento' : 'Stay tuned';
  String get comingSoonDescription => locale.languageCode == 'es' 
      ? 'Estamos trabajando en esta función. Será lanzada pronto.'
      : 'We are working on this feature. It will be released soon.';

  // Common
  String get cancel => locale.languageCode == 'es' ? 'Cancelar' : 'Cancel';
  String get save => locale.languageCode == 'es' ? 'Guardar' : 'Save';
  String get edit => locale.languageCode == 'es' ? 'Editar' : 'Edit';
  String get delete => locale.languageCode == 'es' ? 'Eliminar' : 'Delete';
  String get create => locale.languageCode == 'es' ? 'Crear' : 'Create';
  String get add => locale.languageCode == 'es' ? 'Agregar' : 'Add';
  String get close => locale.languageCode == 'es' ? 'Cerrar' : 'Close';
  String get language => locale.languageCode == 'es' ? 'Idioma' : 'Language';
  String get yes => locale.languageCode == 'es' ? 'Sí' : 'Yes';
  String get no => locale.languageCode == 'es' ? 'No' : 'No';
  String get ok => locale.languageCode == 'es' ? 'OK' : 'OK';
  String get error => locale.languageCode == 'es' ? 'Error' : 'Error';
  String get success => locale.languageCode == 'es' ? 'Éxito' : 'Success';
  String get loading => locale.languageCode == 'es' ? 'Cargando...' : 'Loading...';
  String get retry => locale.languageCode == 'es' ? 'Reintentar' : 'Retry';
  String get offline => locale.languageCode == 'es' ? 'Sin conexión' : 'Offline';
  String get online => locale.languageCode == 'es' ? 'En línea' : 'Online';

  // Submit Screen
  String get enterAchuarPhrase => locale.languageCode == 'es' ? 'Ingrese la frase en Achuar' : 'Enter the phrase in Achuar';
  String get enterSpanishTranslation => locale.languageCode == 'es' ? 'Ingrese la traducción en Español' : 'Enter the Spanish translation';
  String get location => locale.languageCode == 'es' ? 'Ubicación' : 'Location';
  String get selectLocation => locale.languageCode == 'es' ? 'Seleccione una ubicación' : 'Select a location';
  String get additionalNotes => locale.languageCode == 'es' ? 'Notas adicionales' : 'Additional notes';
  String get additionalInfo => locale.languageCode == 'es' ? 'Agregue cualquier información adicional (opcional)' : 'Add any additional information (optional)';
  String get submitContribution => locale.languageCode == 'es' ? 'Enviar contribución' : 'Submit contribution';
  String get savedLocally => locale.languageCode == 'es' ? 'Guardado localmente' : 'Saved locally';
  String get contributionSavedOffline => locale.languageCode == 'es' ? 'Tu contribución ha sido guardada y se subirá automáticamente cuando te conectes a internet.' : 'Your contribution has been saved and will be uploaded automatically when you connect to the internet.';
  String get contributionSent => locale.languageCode == 'es' ? 'Tu contribución ha sido enviada con éxito.' : 'Your contribution has been sent successfully.';

  // Animal List Screen
  String get editModeTitle => locale.languageCode == 'es' ? 'Modo de Edición' : 'Edit Mode';
  String get enterPasswordEdit => locale.languageCode == 'es' ? 'Ingresa la contraseña para activar el modo de edición:' : 'Enter the password to activate edit mode:';
  String get editModeActivated => locale.languageCode == 'es' ? 'Modo de edición activado' : 'Edit mode activated';
  String get incorrectPasswordError => locale.languageCode == 'es' ? 'Contraseña incorrecta' : 'Incorrect password';
  String get spanish => locale.languageCode == 'es' ? 'Español' : 'Spanish';
  String get english => locale.languageCode == 'es' ? 'Inglés' : 'English';
  String get offlineData => locale.languageCode == 'es' ? 'Datos sin conexión' : 'Offline data';
  String get offlineModeTitle => locale.languageCode == 'es' ? 'Modo sin conexión' : 'Offline mode';
  String get noOfflineData => locale.languageCode == 'es' ? 'No se encontraron datos sin conexión' : 'No offline data found';
  String get connectToDownload => locale.languageCode == 'es' ? 'Conéctata a internet para descargar la lista' : 'Connect to the internet to download the list';
  String get downloadWhenConnected => locale.languageCode == 'es' ? 'Descarga los recursos cuando tengas conexión' : 'Download resources when you have a connection';
  String get dataWillSaveAutomatically => locale.languageCode == 'es' ? 'Los datos se guardarán automáticamente' : 'Data will be saved automatically';
  String get tryOtherTerms => locale.languageCode == 'es' ? 'Intenta con otros términos de búsqueda' : 'Try other search terms';
  String get englishName => locale.languageCode == 'es' ? 'Nombre en Inglés' : 'English Name';
  String get spanishName => locale.languageCode == 'es' ? 'Nombre en Español' : 'Spanish Name';

  // Dictionary Screen
  String get searchInDictionary => locale.languageCode == 'es' ? 'Buscar en inglés, achuar o español...' : 'Search in English, Achuar or Spanish...';
  String get swipeToSeeMore => locale.languageCode == 'es' ? 'Desliza para ver más letras' : 'Swipe to see more letters';
  String get dictionaryEmpty => locale.languageCode == 'es' ? 'El diccionario está vacío' : 'The dictionary is empty';

  // Pending Screen
  String get pending => locale.languageCode == 'es' ? 'Pendiente' : 'Pending';
  String get refresh => locale.languageCode == 'es' ? 'Refrescar' : 'Refresh';
  String get pendingItem => locale.languageCode == 'es' ? 'elemento pendiente' : 'pending item';
  String get pendingItems => locale.languageCode == 'es' ? 'elementos pendientes' : 'pending items';
  String get pendingDeletions => locale.languageCode == 'es' ? 'Eliminaciones Pendientes' : 'Pending Deletions';
  String get markAsReviewed => locale.languageCode == 'es' ? 'Marcar como revisado' : 'Mark as reviewed';
  String get markAsNotReviewed => locale.languageCode == 'es' ? 'Marcar como no revisado' : 'Mark as not reviewed';
  String get editPending => locale.languageCode == 'es' ? 'Edición pendiente' : 'Edit pending';
  String get deletionPending => locale.languageCode == 'es' ? 'Eliminación pendiente' : 'Deletion pending';

  // Recent Screen
  String get deleteConfirmation => locale.languageCode == 'es' ? '¿Estás seguro de que deseas eliminar esta entrada? Esta acción no se puede deshacer.' : 'Are you sure you want to delete this entry? This action cannot be undone.';
  String get deleteError => locale.languageCode == 'es' ? 'Error al eliminar la entrada' : 'Error deleting entry';

  // Custom Lesson Screen
  String get enterLessonName => locale.languageCode == 'es' ? 'Por favor, ingresa un nombre para la lección.' : 'Please enter a name for the lesson.';
  String get nameRequirements => locale.languageCode == 'es' ? 'El nombre debe tener al menos 3 caracteres y solo letras, números, guiones, espacios, !, ?, (, ), o apóstrofes.' : 'The name must have at least 3 characters and only letters, numbers, hyphens, spaces, !, ?, (, ), or apostrophes.';
  String get lessonNameExists => locale.languageCode == 'es' ? 'Ya existe una lección con ese nombre.' : 'A lesson with that name already exists.';
  String get addValidPhrase => locale.languageCode == 'es' ? 'Agrega al menos una frase válida.' : 'Add at least one valid phrase.';
  String get lessonSaved => locale.languageCode == 'es' ? 'Lección guardada correctamente.' : 'Lesson saved successfully.';
  String get errorSavingLesson => locale.languageCode == 'es' ? 'Error al guardar la lección' : 'Error saving lesson';
  String get downloadModels => locale.languageCode == 'es' ? 'Descargar modelos' : 'Download models';

  // Learning Mode Screen
  String get next => locale.languageCode == 'es' ? 'Siguiente' : 'Next';
  String get finish => locale.languageCode == 'es' ? 'Finalizar' : 'Finish';
  String get restart => locale.languageCode == 'es' ? 'Reiniciar' : 'Restart';

  // Teaching Resources Screen
  String get teachingResourcesTitle => locale.languageCode == 'es' ? 'Recursos de Enseñanza' : 'Teaching Resources';

  // Submission Tabs Screen
  String get submit => locale.languageCode == 'es' ? 'Enviar' : 'Submit';
  String get recent => locale.languageCode == 'es' ? 'Recientes' : 'Recent';
  String get pendingTab => locale.languageCode == 'es' ? 'Pendientes' : 'Pending';

  // Common Error Messages
  String get noConnection => locale.languageCode == 'es' ? 'Sin conexión' : 'No connection';
  String get translateToEnglish => locale.languageCode == 'es' ? 'Traducir al inglés' : 'Translate to English';
  String get noConnectionDownloadModels => locale.languageCode == 'es' ? 'Sin conexión. Conéctese a internet para descargar los modelos de traducción.' : 'No connection. Connect to the internet to download translation models.';
  String get downloadingModelsStay => locale.languageCode == 'es' ? 'Descargando modelos... Por favor, no abandone esta página.' : 'Downloading models... Please do not leave this page.';
  String get noConnectionDownloadList => locale.languageCode == 'es' ? 'Sin conexión. Conéctese a internet para descargar la lista.' : 'No connection. Connect to the internet to download the list.';
  String get couldNotDownloadAudio => locale.languageCode == 'es' ? 'No se pudo descargar ningún audio.' : 'Could not download any audio.';
  String get audioNotAvailableOfflineShort => locale.languageCode == 'es' ? 'Audio no disponible sin conexión.' : 'Audio not available offline.';
  String get translationAlreadyInList => locale.languageCode == 'es' ? 'Esta traducción ya está en la lista.' : 'This translation is already in the list.';
  String get confirmDeleteList => locale.languageCode == 'es' ? '¿Estás seguro de que quieres eliminar esta lista?' : 'Are you sure you want to delete this list?';
  String get actionCannotBeUndone => locale.languageCode == 'es' ? 'Esta acción no se puede deshacer.' : 'This action cannot be undone.';
  String get emptyList => locale.languageCode == 'es' ? 'Lista vacía' : 'Empty list';
  String get noTranslationsYet => locale.languageCode == 'es' ? 'No hay traducciones en esta lista aún.\nAgrega traducciones desde el traductor.' : 'No translations in this list yet.\nAdd translations from the translator.';
  String get offlineTranslationModel => locale.languageCode == 'es' ? 'Modelos de traducción offline' : 'Offline translation models';
  String get downloadModelsOffline => locale.languageCode == 'es' ? 'Descarga los modelos para traducir sin conexión a internet' : 'Download models to translate without internet connection';

  // Guide Categories specific
  String get downloadingImages => locale.languageCode == 'es' ? 'Descargando imágenes...' : 'Downloading images...';
  String get keepAppOpen => locale.languageCode == 'es' ? 'Por favor, mantenga la aplicación abierta' : 'Please keep the app open';
  String get someAudioOutdated => locale.languageCode == 'es' ? 'Algunos audios descargados están desactualizados' : 'Some downloaded audio is outdated';
  String get doNotLeave => locale.languageCode == 'es' ? 'Por favor, no abandone esta página mientras se descarga.' : 'Please do not leave this page while downloading.';
  String get resourcesDownloadedSuccess => locale.languageCode == 'es' ? 'Recursos, imágenes y audio descargados con éxito!' : 'Resources, images and audio downloaded successfully!';

  // Welcome Screen
  String get usernameNotFound => locale.languageCode == 'es' ? 'Nombre de usuario no encontrado. Inténtelo de nuevo.' : 'Username not found. Please try again.';
  String get errorSearchingUser => locale.languageCode == 'es' ? 'Error al buscar el usuario. Inténtelo de nuevo.' : 'Error searching for user. Please try again.';
  String get lettersUpperLower => locale.languageCode == 'es' ? 'Letras (mayúsculas o minúsculas)' : 'Letters (uppercase or lowercase)';
  String get numbers => locale.languageCode == 'es' ? 'Números' : 'Numbers';
  String get validExamples => locale.languageCode == 'es' ? 'Ejemplos válidos:' : 'Valid examples:';
  String get createUniqueUsername => locale.languageCode == 'es' ? 'Cree un nombre de usuario único' : 'Create a unique username';
  String get usernameRequirements => locale.languageCode == 'es' ? 'El nombre de usuario solo puede contener letras, números o guiones bajos (_), sin espacios.' : 'Username can only contain letters, numbers or underscores (_), no spaces.';
  String get errorCreatingUser => locale.languageCode == 'es' ? 'Error al crear el usuario. Inténtelo de nuevo.' : 'Error creating user. Please try again.';

  // Additional Dictionary Screen
  String get words => locale.languageCode == 'es' ? 'Palabras' : 'Words';

  // Additional Translator Screen
  String get createNewList => locale.languageCode == 'es' ? 'Crear nueva lista' : 'Create new list';
  String get listName => locale.languageCode == 'es' ? 'Nombre de la lista' : 'List name';
  String get enterListName => locale.languageCode == 'es' ? 'Ingrese el nombre de la lista' : 'Enter list name';

  // Level Names for Teaching Resources
  String get basicLevel => locale.languageCode == 'es' ? 'Básico' : 'Basic';
  String get intermediateLevel => locale.languageCode == 'es' ? 'Intermedio' : 'Intermediate';
  String get advancedLevel => locale.languageCode == 'es' ? 'Avanzado' : 'Advanced';
  String get practiceVocabulary => locale.languageCode == 'es' ? 'Practica vocabulario' : 'Practice vocabulary';
  String get learnBasicPhrases => locale.languageCode == 'es' ? 'Aprende frases básicas' : 'Learn basic phrases';
  String get expandYourVocabulary => locale.languageCode == 'es' ? 'Amplía tu vocabulario' : 'Expand your vocabulary';
  String get masterComplexSentences => locale.languageCode == 'es' ? 'Domina oraciones complejas' : 'Master complex sentences';

  // Lesson Screen
  String get searchWords => locale.languageCode == 'es' ? 'Buscar palabras' : 'Search words';
  String get searchInLesson => locale.languageCode == 'es' ? 'Buscar en la lección...' : 'Search in lesson...';
  String get practiceMode => locale.languageCode == 'es' ? 'Modo de práctica' : 'Practice mode';
  String get studyMode => locale.languageCode == 'es' ? 'Modo de estudio' : 'Study mode';
  String get showTranslation => locale.languageCode == 'es' ? 'Mostrar traducción' : 'Show translation';
  String get hideTranslation => locale.languageCode == 'es' ? 'Ocultar traducción' : 'Hide translation';

  // Learning Mode Screen
  String get question => locale.languageCode == 'es' ? 'Pregunta' : 'Question';
  String get ofPreposition => locale.languageCode == 'es' ? 'de' : 'of';
  String get answer => locale.languageCode == 'es' ? 'Respuesta' : 'Answer';
  String get correct => locale.languageCode == 'es' ? 'Correcto' : 'Correct';
  String get incorrect => locale.languageCode == 'es' ? 'Incorrecto' : 'Incorrect';
  String get correctExclamation => locale.languageCode == 'es' ? '¡Correcto!' : 'Correct!';
  String get incorrectExclamation => locale.languageCode == 'es' ? '¡Incorrecto!' : 'Incorrect!';
  String get correctAnswerIs => locale.languageCode == 'es' ? 'La respuesta correcta es:' : 'The correct answer is:';
  String get listenAndSelect => locale.languageCode == 'es' ? 'Escucha y selecciona la palabra correcta' : 'Listen and select the correct word';
  String get writeTranslationHere => locale.languageCode == 'es' ? 'Escribe la traducción aquí...' : 'Write the translation here...';
  String get arrangeWordsPhrase => locale.languageCode == 'es' ? 'Ordena las palabras para formar la frase correcta' : 'Arrange the words to form the correct phrase';
  String get tapWordsToBuild => locale.languageCode == 'es' ? 'Toca las palabras abajo para construir la frase' : 'Tap the words below to build the phrase';
  String get learningMode => locale.languageCode == 'es' ? 'Modo de Aprendizaje' : 'Learning Mode';
  String get resumeOrStartNew => locale.languageCode == 'es' ? '¿Desea reanudar la sesión anterior o comenzar una nueva?' : 'Do you want to resume the previous session or start a new one?';
  String get resume => locale.languageCode == 'es' ? 'Reanudar' : 'Resume';
  String get newSession => locale.languageCode == 'es' ? 'Nueva Sesión' : 'New Session';
  String get startLearningMode => locale.languageCode == 'es' ? 'Iniciar Modo de Aprendizaje' : 'Start Learning Mode';
  String get continueYourProgress => locale.languageCode == 'es' ? 'Continua tu progreso' : 'Continue your progress';
  String get practiceInteractive => locale.languageCode == 'es' ? 'Practica con ejercicios interactivos' : 'Practice with interactive exercises';
  String get score => locale.languageCode == 'es' ? 'Puntuación' : 'Score';
  String get completedQuestions => locale.languageCode == 'es' ? 'Preguntas completadas' : 'Completed questions';
  String get totalQuestions => locale.languageCode == 'es' ? 'Total de preguntas' : 'Total questions';
  String get congratulations => locale.languageCode == 'es' ? '¡Felicitaciones!' : 'Congratulations!';
  String get lessonsCompleted => locale.languageCode == 'es' ? 'Lecciones completadas' : 'Lessons completed';
  String get practiceCompleted => locale.languageCode == 'es' ? 'Práctica completada' : 'Practice completed';
  String get yourScore => locale.languageCode == 'es' ? 'Tu puntuación' : 'Your score';
  String get excellentWork => locale.languageCode == 'es' ? '¡Excelente trabajo!' : 'Excellent work!';
  String get goodJob => locale.languageCode == 'es' ? '¡Buen trabajo!' : 'Good job!';
  String get keepPracticing => locale.languageCode == 'es' ? '¡Sigue practicando!' : 'Keep practicing!';
  String get tryAgain => locale.languageCode == 'es' ? 'Intentar de nuevo' : 'Try again';
  String get backToLessons => locale.languageCode == 'es' ? 'Volver a lecciones' : 'Back to lessons';

  // Recent Contributions Screen
  String get recentContributionsTitle => locale.languageCode == 'es' ? 'Contribuciones Recientes' : 'Recent Contributions';
  String get noRecentContributions => locale.languageCode == 'es' ? 'No hay contribuciones recientes' : 'No recent contributions';
  String get loadingContributions => locale.languageCode == 'es' ? 'Cargando contribuciones...' : 'Loading contributions...';
  String get editEntry => locale.languageCode == 'es' ? 'Editar' : 'Edit';
  String get deleteEntry => locale.languageCode == 'es' ? 'Eliminar entrada' : 'Delete entry';
  String get deleteEntryConfirmation => locale.languageCode == 'es' ? '¿Estás seguro de que quieres eliminar esta entrada?' : 'Are you sure you want to delete this entry?';
  String get entryUpdated => locale.languageCode == 'es' ? 'Entrada actualizada' : 'Entry updated';
  String get entryDeleted => locale.languageCode == 'es' ? 'Entrada eliminada' : 'Entry deleted';

  // Pending Screen specific
  String get pendingContributions => locale.languageCode == 'es' ? 'Contribuciones Pendientes' : 'Pending Contributions';
  String get pendingEdits => locale.languageCode == 'es' ? 'Ediciones Pendientes' : 'Pending Edits';
  String get noPendingContributions => locale.languageCode == 'es' ? 'No hay contribuciones pendientes' : 'No pending contributions';
  String get syncWhenOnline => locale.languageCode == 'es' ? 'Se sincronizará cuando esté en línea' : 'Will sync when online';
  String get retrySync => locale.languageCode == 'es' ? 'Reintentar sincronización' : 'Retry sync';
  String get noPendingItems => locale.languageCode == 'es' ? 'No hay elementos pendientes' : 'No pending items';
  String get allContributionsUpToDate => locale.languageCode == 'es' ? 'Todas tus contribuciones están al día' : 'All your contributions are up to date';
  String get everythingSynchronized => locale.languageCode == 'es' ? 'Todo sincronizado' : 'Everything synchronized';
  String get itemsWillSyncAutomatically => locale.languageCode == 'es' ? 'Los elementos se sincronizarán automáticamente' : 'Items will sync automatically';

  // Recent Screen additional
  String get yourSubmissions => locale.languageCode == 'es' ? 'Tus envíos' : 'Your submissions';
  String get allSubmissions => locale.languageCode == 'es' ? 'Todos los envíos' : 'All submissions';
  String get searchPhrases => locale.languageCode == 'es' ? 'Buscar frases...' : 'Search phrases...';
  String get editPhrase => locale.languageCode == 'es' ? 'Editar Frase' : 'Edit Phrase';

  String get reviewed => locale.languageCode == 'es' ? 'Revisado' : 'Reviewed';
  String get loadingContributionsEllipsis => locale.languageCode == 'es' ? 'Cargando contribuciones...' : 'Loading contributions...';
  String get noSearchResults => locale.languageCode == 'es' ? 'No se encontraron resultados' : 'No search results found';
  String get incorrectPasswordMessage => locale.languageCode == 'es' ? 'Contraseña incorrecta' : 'Incorrect password';
  String get revisionChangeSaved => locale.languageCode == 'es' ? 'Cambio de revisión guardado para sincronizar.' : 'Review change saved to sync.';
  String get errorUpdatingRevision => locale.languageCode == 'es' ? 'Error al actualizar la revisión' : 'Error updating revision';
  String get errorSavingEdit => locale.languageCode == 'es' ? 'Error al guardar la edición' : 'Error saving edit';
  String get errorDeletingEntry => locale.languageCode == 'es' ? 'Error al eliminar la entrada' : 'Error deleting entry';
  String get syncedSuccessfully => locale.languageCode == 'es' ? 'Sincronizado correctamente' : 'Synced successfully';
  String get errorSyncing => locale.languageCode == 'es' ? 'Error al sincronizar' : 'Error syncing';

  // Submission Tabs Screen
  String get recentSubmissions => locale.languageCode == 'es' ? 'Recientes' : 'Recent';
  String get pendingSubmissions => locale.languageCode == 'es' ? 'Pendientes' : 'Pending';

  // Additional strings for UI elements
  String get errorDeletingEntryPrefix => locale.languageCode == 'es' ? 'Error al eliminar la entrada' : 'Error deleting entry';
  String get selectExistingList => locale.languageCode == 'es' ? 'Selecciona una lista existente:' : 'Select an existing list:';
  String get selectList => locale.languageCode == 'es' ? 'Selecciona una lista' : 'Select a list';
  String get orCreateNewList => locale.languageCode == 'es' ? 'O crea una nueva lista:' : 'Or create a new list:';
  String get invalidQuestionType => locale.languageCode == 'es' ? 'Error: Tipo de pregunta no válido' : 'Error: Invalid question type';
  String get noConnectionDownloadAudio => locale.languageCode == 'es' ? 'Sin conexión. Descargue el audio para usarlo sin conexión.' : 'No connection. Download audio for offline use.';
  String get check => locale.languageCode == 'es' ? 'Comprobar' : 'Check';
  String get animalUpdatedSuccessfully => locale.languageCode == 'es' ? 'Animal actualizado exitosamente' : 'Animal updated successfully';
  String get errorSaving => locale.languageCode == 'es' ? 'Error al guardar' : 'Error saving';
  String get errorDownloadingModels => locale.languageCode == 'es' ? 'Error al descargar modelos' : 'Error downloading models';
  String get noConnectionDownloadModelsOrConnect => locale.languageCode == 'es' ? 'Sin conexión. Descargue los modelos o conéctese a internet.' : 'No connection. Download models or connect to internet.';
  String get errorTranslating => locale.languageCode == 'es' ? 'Error al traducir' : 'Error translating';
  String get englishAuto => locale.languageCode == 'es' ? 'Inglés (auto)' : 'English (auto)';
  String get translate => locale.languageCode == 'es' ? 'Traducir' : 'Translate';
  String get addPhrase => locale.languageCode == 'es' ? 'Agregar frase' : 'Add phrase';
  String get lessonDeleted => locale.languageCode == 'es' ? 'Lección eliminada' : 'Lesson deleted';
  String get pleaseCompleteRequiredFields => locale.languageCode == 'es' ? 'Por favor, complete los campos obligatorios' : 'Please complete required fields';
  String get doNotLeaveWhileDownloading => locale.languageCode == 'es' ? 'Por favor, no abandone esta página mientras se descarga.' : 'Please do not leave this page while downloading.';
  String get resourcesImagesAudioDownloaded => locale.languageCode == 'es' ? 'Recursos, imágenes y audio descargados con éxito!' : 'Resources, images and audio downloaded successfully!';
  String get couldNotPlayAudioError => locale.languageCode == 'es' ? 'No se pudo reproducir el audio' : 'Could not play audio';
  String get changesSavedSuccessfully => locale.languageCode == 'es' ? 'Cambios guardados exitosamente' : 'Changes saved successfully';
  String get translationWillAppear => locale.languageCode == 'es' ? 'Traducción aparecerá aquí...' : 'Translation will appear here...';
  String get addToList => locale.languageCode == 'es' ? 'Agregar a lista' : 'Add to list';
  String get deleteLessonTitle => locale.languageCode == 'es' ? 'Eliminar lección' : 'Delete lesson';
  String get deleteLessonConfirmation => locale.languageCode == 'es' ? '¿Estás seguro de que deseas eliminar la lección' : 'Are you sure you want to delete the lesson';
  String get deleteListTitle => locale.languageCode == 'es' ? 'Eliminar lista' : 'Delete list';
  String get redownloadLessonMessage => locale.languageCode == 'es' ? 'No se pudo reproducir el audio. Redescargue la lección cuando esté en línea para actualizar el audio.' : 'Could not play audio. Re-download the lesson when online to update the audio.';
  String get downloadingModelsStayOnPage => locale.languageCode == 'es' ? 'Descargando modelos... Por favor, no abandone esta página.' : 'Downloading models... Please do not leave this page.';
  String get areYouSureDeleteList => locale.languageCode == 'es' ? '¿Estás seguro de que quieres eliminar esta lista?' : 'Are you sure you want to delete this list?';
  String get modelsDownloadedSuccessfully => locale.languageCode == 'es' ? '¡Modelos descargados exitosamente!' : 'Models downloaded successfully!';
  String get listDownloadedSuccessfully => locale.languageCode == 'es' ? 'Lista descargada exitosamente.' : 'List downloaded successfully.';
  String get listNameAlreadyExists => locale.languageCode == 'es' ? 'Ya existe una lista con ese nombre.' : 'A list with that name already exists.';
  String get lessonNameAlreadyExistsMessage => locale.languageCode == 'es' ? 'Ya existe una lección con ese nombre.' : 'A lesson with that name already exists.';
  String listDownloadedWithErrors(int errors) => locale.languageCode == 'es' ? 'Lista descargada con $errors errores.' : 'List downloaded with $errors errors.';
  String get couldNotDownloadAnyAudio => locale.languageCode == 'es' ? 'No se pudo descargar ningún audio.' : 'Could not download any audio.';
  String listCreated(String name) => locale.languageCode == 'es' ? 'Lista "$name" creada.' : 'List "$name" created.';
  String get pleaseEnterListName => locale.languageCode == 'es' ? 'Por favor ingresa un nombre para la lista.' : 'Please enter a name for the list.';
  String get errorDownloading => locale.languageCode == 'es' ? 'Error al descargar' : 'Error downloading';
  String get errorOpeningEditor => locale.languageCode == 'es' ? 'Error opening editor' : 'Error opening editor';
  String get noEnglishPhrasesToDownload => locale.languageCode == 'es' ? 'No hay frases en inglés para descargar en esta lección.' : 'No English phrases to download in this lesson.';
  String get errorOpeningLessonCreator => locale.languageCode == 'es' ? 'Error opening lesson creator' : 'Error opening lesson creator';
  String get editPendingSync => locale.languageCode == 'es' ? 'Edición pendiente de sincronización' : 'Edit pending sync';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['es', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
