# language: en
@nucleo
Feature: Transferir dinero
  Como cliente
  Quiero enviar dinero a otro usuario Qolqe o a otro banco
  Para pagar de inmediato

  Background:
    Given que los datos de prueba están restaurados
    And que la fecha de la app es "2026-11-10T10:00:00"

  @HU-N-07 @api
  Scenario: Transferencia exitosa a un usuario registrado
    Given que inicié sesión como Ana
    When transfiero S/ 100.00 al celular 912345678
    Then el resultado es "exitosa"
    And la transferencia tiene un código de operación
    And mi saldo es S/ 1400.00
    And el celular 912345678 recibe un SMS que contiene "100.00"

  @HU-N-07 @api
  Scenario Outline: Validación del monto por operación (RN-05)
    Given que inicié sesión como Ana
    When transfiero S/ <monto> al celular 912345678
    Then el resultado es "<resultado>"

    Examples:
      | monto  | resultado      |
      | 0.00   | MONTO_INVALIDO |
      | 0.01   | exitosa        |
      | 500.00 | exitosa        |
      | 500.01 | MONTO_INVALIDO |
      | 10.005 | MONTO_INVALIDO |

  @HU-N-07 @api
  Scenario Outline: Destinos no permitidos (RN-07)
    Given que inicié sesión como Ana
    When transfiero S/ 10.00 al celular <celular>
    Then el resultado es "<resultado>"

    Examples:
      | celular   | resultado                |
      | 987654321 | TRANSFERENCIA_A_SI_MISMO |
      | 900999999 | DESTINO_NO_REGISTRADO    |

    @DEF-06 @fail
    Examples: Cuenta cerrada
      | celular   | resultado        |
      | 934567812 | DESTINO_INACTIVO |

  @HU-N-07 @api
  Scenario: El saldo debe cubrir el monto (RN-08)
    Given que inicié sesión como Carla
    When transfiero S/ 50.01 al celular 912345678
    Then el resultado es "SALDO_INSUFICIENTE"

  @HU-N-07 @rendimiento @skip
  Scenario: Transferencias simultáneas no superan el límite ni dejan saldo negativo
    # Se ejecuta en la Parte 3 (rendimiento)
    Given que inicié sesión como Diego
    When envío 5 transferencias simultáneas de S/ 300.00 al celular 912345678
    Then lo usado hoy no supera S/ 1000.00

  @HU-N-08 @api
  Scenario Outline: Validación del CCI
    Given que inicié sesión como Ana
    When transfiero S/ 100.00 al CCI <cci>
    Then el resultado es "<resultado>"

    Examples:
      | cci                   | resultado   |
      | 0021930012345678901   | CCI_INVALIDO |
      | 00219300123456789012  | exitosa      |
      | 002193001234567890123 | CCI_INVALIDO |

  @HU-N-08 @api @DEF-04 @fail
  Scenario: El saldo debe cubrir el monto más la comisión interbancaria
    Given que inicié sesión como Carla
    When transfiero S/ 50.00 a otro banco
    Then el resultado es "SALDO_INSUFICIENTE"
    And mi saldo es S/ 50.00

  @HU-N-09 @api
  Scenario Outline: Simular la comisión sin realizar la operación (RN-09)
    Given que inicié sesión como Ana
    When simulo la comisión de S/ <monto> a otro banco
    Then la comisión es S/ <comision> y el total S/ <total>
    And mi saldo es S/ 1500.00

    Examples:
      | monto  | comision | total  |
      | 50.00  | 1.00     | 51.00  |
      | 66.67  | 1.00     | 67.67  |
      | 100.00 | 1.50     | 101.50 |
      | 333.33 | 5.00     | 338.33 |
      | 400.00 | 5.00     | 405.00 |
