# language: en
@nucleo
Feature: Iniciar y cerrar sesión
  Como cliente
  Quiero ingresar con mi celular y PIN
  Para acceder a mi cuenta de forma segura

  Background:
    Given que los datos de prueba están restaurados
    And que la fecha de la app es "2026-11-10T10:00:00"

  @HU-N-02 @api
  Scenario: Ingreso con credenciales correctas
    When inicio sesión con el celular 987654321 y el PIN 4826
    Then recibo un token válido por 30 minutos

  @HU-N-02 @api
  Scenario Outline: Credenciales incorrectas con mensaje genérico
    When inicio sesión con el celular <celular> y el PIN <pin>
    Then el resultado es "CREDENCIALES_INVALIDAS"
    And la respuesta tiene el código HTTP 401

    Examples:
      | celular   | pin  |
      | 987654321 | 1111 |
      | 900999999 | 4826 |

  @HU-N-02 @api
  Scenario: Bloqueo al tercer intento fallido consecutivo
    Given que ya fallé 2 veces el PIN del celular 912345678
    When inicio sesión con el celular 912345678 y el PIN 0000
    Then el resultado es "CUENTA_BLOQUEADA"
    And la respuesta tiene el código HTTP 423
    And el celular 912345678 recibe un SMS que contiene "bloqueada"

  @HU-N-02 @api
  Scenario Outline: Durante el bloqueo ni el PIN correcto permite ingresar
    Given que la cuenta del celular 912345678 quedó bloqueada
    When pasan <minutos> minutos
    And inicio sesión con el celular 912345678 y el PIN 7391
    Then el resultado es "<resultado>"

    Examples:
      | minutos | resultado        |
      | 14      | CUENTA_BLOQUEADA |
      | 15      | exitosa          |

  @HU-N-02 @api @DEF-08 @fail
  Scenario: Un ingreso exitoso reinicia el conteo de intentos
    Given que ya fallé 2 veces el PIN del celular 912345678
    And que inicié sesión como Bruno
    When inicio sesión con el celular 912345678 y el PIN 0000
    Then el resultado es "CREDENCIALES_INVALIDAS"

  @HU-N-02 @api
  Scenario: Una cuenta cerrada no puede iniciar sesión
    When inicio sesión con el celular 934567812 y el PIN 6029
    Then el resultado es "CUENTA_CERRADA"

  @HU-N-03 @api @DEF-07 @fail
  Scenario: Al cerrar sesión el token deja de ser válido
    Given que inicié sesión como Ana
    When cierro sesión
    Then mi token anterior responde 401

  @HU-N-03 @api
  Scenario: Cerrar una sesión no afecta las otras sesiones activas
    Given que inicié sesión como Ana en dos equipos
    When cierro sesión en el primer equipo
    Then el segundo equipo sigue consultando mi saldo
