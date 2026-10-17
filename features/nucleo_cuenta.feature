# language: en
@nucleo
Feature: Mi cuenta: saldo, perfil y cierre
  Como cliente
  Quiero consultar y mantener mis datos
  Para controlar mi cuenta

  Background:
    Given que los datos de prueba están restaurados
    And que la fecha de la app es "2026-11-10T10:00:00"

  @HU-N-04 @api
  Scenario: Consulto mi saldo en soles
    Given que inicié sesión como Ana
    When consulto mi saldo
    Then mi saldo es S/ 1500.00
    And la moneda es "PEN"

  @HU-N-04 @api
  Scenario: Mi perfil muestra el DNI enmascarado
    Given que inicié sesión como Ana
    When consulto mi perfil
    Then el DNI se muestra con solo los últimos 4 dígitos

  @HU-N-04 @api
  Scenario: Sin token no puedo consultar mi saldo
    When consulto el saldo sin token
    Then el resultado es "NO_AUTENTICADO"

  @HU-N-05 @api
  Scenario: Cambiar el correo envía un SMS de aviso
    Given que inicié sesión como Ana
    When cambio mi correo a "ana.nueva@correo.pe"
    Then el resultado es "exitosa"
    And el celular 987654321 recibe un SMS que contiene "ana.nueva@correo.pe"

  @HU-N-05 @api
  Scenario: El correo de otra cuenta activa no se puede usar
    Given que inicié sesión como Ana
    When cambio mi correo a "Bruno.Diaz@correo.pe"
    Then el resultado es "CORREO_REGISTRADO"

  @HU-N-05 @api
  Scenario: El DNI y el celular no se pueden modificar
    Given que inicié sesión como Ana
    When intento cambiar mi celular a "999999999"
    Then mi perfil sigue con el celular 987654321

  @HU-N-06 @api
  Scenario Outline: Reglas para cerrar mi cuenta
    Given que inicié sesión como <usuario>
    And que mi saldo es S/ <saldo>
    When cierro mi cuenta con el PIN <pin>
    Then el resultado es "<resultado>"

    Examples:
      | usuario | saldo | pin  | resultado              |
      | Carla   | 0.00  | 1111 | PIN_INCORRECTO         |
      | Carla   | 0.01  | 5917 | SALDO_PENDIENTE        |
      | Ana     | 0.00  | 4826 | SOLICITUDES_PENDIENTES |
      | Carla   | 0.00  | 5917 | exitosa                |

  @HU-N-06 @api @DEF-06 @fail
  Scenario: Tras cerrar la cuenta nadie puede transferirme
    Given que inicié sesión como Carla
    And que mi saldo es S/ 0.00
    And que cerré mi cuenta con el PIN 5917
    And que inicié sesión como Ana
    When transfiero S/ 10.00 al celular 956781234
    Then el resultado es "DESTINO_INACTIVO"
