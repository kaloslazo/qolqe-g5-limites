# language: en
@nucleo
Feature: Registrarme
  Como visitante
  Quiero crear una cuenta con mi DNI y celular
  Para usar la billetera

  Background:
    Given que los datos de prueba están restaurados
    And que la fecha de la app es "2026-11-10T10:00:00"

  @HU-N-01 @api
  Scenario: Registro exitoso con saldo cero, límite por defecto y SMS de bienvenida
    When me registro con DNI "45678912", celular "987000111" y PIN "4826"
    Then la respuesta tiene el código HTTP 201
    And el celular 987000111 recibe un SMS que contiene "Bienvenido a Qolqe"
    And al iniciar sesión con el celular 987000111 y el PIN 4826 mi saldo es S/ 0.00
    And mi límite diario vigente es S/ 2000.00

  @HU-N-01 @api
  Scenario Outline: Validación del DNI (RN-01)
    When me registro con DNI "<dni>", celular "987000111" y PIN "4826"
    Then el resultado es "<resultado>"

    Examples:
      | dni       | resultado    |
      | 1234567   | DNI_INVALIDO |
      | 12345678  | exitosa      |
      | 123456789 | DNI_INVALIDO |
      | 1234567A  | DNI_INVALIDO |

  @HU-N-01 @api
  Scenario Outline: Validación del celular (RN-02)
    When me registro con DNI "45678912", celular "<celular>" y PIN "4826"
    Then el resultado es "<resultado>"

    Examples:
      | celular    | resultado          |
      | 98700011   | CELULAR_INVALIDO   |
      | 9870001112 | CELULAR_INVALIDO   |
      | 887000111  | CELULAR_INVALIDO   |
      | 987654321  | CELULAR_REGISTRADO |
      | 934567812  | CELULAR_REGISTRADO |

  @HU-N-01 @api
  Scenario Outline: Validación del PIN (RN-03)
    When me registro con DNI "45678912", celular "987000111" y PIN "<pin>"
    Then el resultado es "<resultado>"

    Examples:
      | pin   | resultado   |
      | 482   | PIN_INVALIDO |
      | 48260 | PIN_INVALIDO |
      | 1111  | PIN_INVALIDO |
      | 1234  | PIN_INVALIDO |
      | 2580  | exitosa      |

  @HU-N-01 @api @DEF-05 @fail
  Scenario: Un PIN en secuencia descendente se rechaza (RN-03)
    When me registro con DNI "45678912", celular "987000111" y PIN "4321"
    Then el resultado es "PIN_INVALIDO"

  @HU-N-01 @api
  Scenario: Correo ya usado por otra cuenta activa, sin distinguir mayúsculas
    When me registro con DNI "45678912", celular "987000111", PIN "4826" y correo "ANA.TORRES@correo.pe"
    Then el resultado es "CORREO_REGISTRADO"

  @HU-N-01 @api @DEF-09 @fail
  Scenario: Dos registros simultáneos con el mismo celular responden 201 y 409, nunca 500
    When 4 visitantes se registran a la vez con el celular "987000111"
    Then una respuesta es 201 y las demás son 409 con "CELULAR_REGISTRADO"
