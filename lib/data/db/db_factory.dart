// Fallback para mobile/desktop (IO). Web substitui abaixo.
export 'db_factory_io.dart'
  if (dart.library.html) 'db_factory_web.dart';
