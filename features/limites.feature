# language: en
@G5 @limites
Feature: Límites y alertas de consumo
  Como cliente de Qolqe
  Quiero controlar mi límite diario de transferencias y recibir alertas de consumo
  Para proteger mi dinero y controlar mis gastos

  Background:
    Given que los datos de prueba están restaurados
    And que la fecha de la app es "2026-11-10T10:00:00"

  # ------------------------------------------------------------------ HU-G5-01
  @HU-G5-01 @api
  Scenario: Veo mis límites con lo usado y lo disponible del día
    Given que inicié sesión como Diego
    And que ya transferí S/ 300.00 hoy al celular 912345678
    When consulto mis límites
    Then el límite por operación es S/ 500.00
    And mi límite diario vigente es S/ 1000.00
    And lo usado hoy es S/ 300.00
    And lo disponible hoy es S/ 700.00

  # ------------------------------------------------------------------ HU-G5-02 (R-G5-01: rango y múltiplos)
  @HU-G5-02 @api
  Scenario Outline: Validación del nuevo límite diario (valores límite de R-G5-01)
    Given que inicié sesión como Ana
    When cambio mi límite diario a S/ <limite>
    Then el resultado es "<resultado>"

    Examples:
      | limite  | resultado       |
      | 50      | LIMITE_INVALIDO |
      | 99.99   | LIMITE_INVALIDO |
      | 100     | INMEDIATA       |
      | 120     | LIMITE_INVALIDO |
      | 150     | INMEDIATA       |
      | 1950    | INMEDIATA       |
      | 2000    | INMEDIATA       |
      | 2050    | LIMITE_INVALIDO |

  # ------------------------------------------------------------------ HU-G5-02 (R-G5-02: reducción vs aumento)
  @HU-G5-02 @api
  Scenario: Una reducción del límite es inmediata
    Given que inicié sesión como Diego
    When cambio mi límite diario a S/ 500
    Then el resultado es "INMEDIATA"
    And mi límite diario vigente es S/ 500.00
    And recibo un SMS que contiene "Tu límite diario ahora es S/ 500"

  @HU-G5-02 @api
  Scenario: Un aumento del límite queda programado para 24 horas después
    Given que inicié sesión como Diego
    When cambio mi límite diario a S/ 1500
    Then el resultado es "PROGRAMADA"
    And mi límite diario vigente es S/ 1000.00
    And tengo un aumento pendiente de S/ 1500.00
    And recibo un SMS que contiene "estará vigente desde"

  @HU-G5-02 @api
  Scenario Outline: El aumento entra en vigencia exactamente a las 24 horas
    Given que inicié sesión como Diego
    And que solicité aumentar mi límite diario a S/ 1500
    When pasan <minutos> minutos
    Then mi límite diario vigente es S/ <vigente>

    Examples:
      | minutos | vigente |
      | 1439    | 1000.00 |
      | 1440    | 1500.00 |

  @HU-G5-02 @api @DEF-01 @fail
  Scenario: Una reducción cancela el aumento pendiente
    Given que inicié sesión como Diego
    And que solicité aumentar mi límite diario a S/ 1500
    When cambio mi límite diario a S/ 500
    And pasan 1500 minutos
    Then mi límite diario vigente es S/ 500.00
    And no tengo un aumento pendiente

  @HU-G5-02 @api
  Scenario: Reducir el límite por debajo del umbral pausa la alerta de transferencias
    Given que inicié sesión como Ana
    When cambio mi límite diario a S/ 250
    Then la alerta de TRANSFERENCIAS con umbral S/ 300 está PAUSADA

  # ------------------------------------------------------------------ HU-G5-03 (RN-06)
  @HU-G5-03 @api
  Scenario Outline: Transferir respetando el límite diario vigente
    Given que inicié sesión como Diego
    And que ya transferí S/ 500.00 hoy al celular 912345678
    When transfiero S/ <monto> al celular 912345678
    Then el resultado es "<resultado>"

    Examples:
      | monto  | resultado              |
      | 499.99 | exitosa                |
      | 500.00 | exitosa                |
      | 500.01 | MONTO_INVALIDO         |

  @HU-G5-03 @api
  Scenario: La transferencia que supera el límite diario por un céntimo se rechaza
    Given que inicié sesión como Diego
    And que ya transferí S/ 500.00 hoy al celular 912345678
    And que ya transferí S/ 500.00 hoy al celular 912345678
    When transfiero S/ 0.01 al celular 912345678
    Then el resultado es "LIMITE_DIARIO_EXCEDIDO"

  @HU-G5-03 @api @DEF-02 @fail
  Scenario: Las transferencias interbancarias también cuentan para el límite diario
    Given que inicié sesión como Diego
    And que ya transferí S/ 500.00 hoy a otro banco
    And que ya transferí S/ 500.00 hoy a otro banco
    When transfiero S/ 0.01 al celular 912345678
    Then el resultado es "LIMITE_DIARIO_EXCEDIDO"

  # ------------------------------------------------------------------ HU-G5-04 (R-G5-03, R-G5-04)
  @HU-G5-04 @api
  Scenario Outline: Validación del umbral de una alerta (valores límite de R-G5-03)
    Given que inicié sesión como Ana
    When creo una alerta de <tipo> con umbral S/ <umbral>
    Then el resultado es "<resultado>"

    Examples:
      | tipo     | umbral | resultado       |
      | RECARGAS | 0      | ALERTA_INVALIDA |
      | RECARGAS | 9.99   | ALERTA_INVALIDA |
      | RECARGAS | 10     | ACTIVA          |
      | RECARGAS | 15     | ALERTA_INVALIDA |
      | RECARGAS | 2000   | ACTIVA          |
      | RECARGAS | 2010   | ALERTA_INVALIDA |
      | AHORROS  | 100    | ALERTA_INVALIDA |

  @HU-G5-04 @api
  Scenario Outline: El umbral de TRANSFERENCIAS o TODAS no supera el límite diario vigente
    Given que inicié sesión como Diego
    When creo una alerta de <tipo> con umbral S/ <umbral>
    Then el resultado es "<resultado>"

    Examples:
      | tipo           | umbral | resultado       |
      | TRANSFERENCIAS | 1000   | ACTIVA          |
      | TRANSFERENCIAS | 1010   | ALERTA_INVALIDA |
      | TODAS          | 1010   | ALERTA_INVALIDA |
      | PAGOS          | 1010   | ACTIVA          |

  @HU-G5-04 @api
  Scenario: No se permiten dos alertas con el mismo tipo y umbral
    Given que inicié sesión como Ana
    When creo una alerta de TRANSFERENCIAS con umbral S/ 300
    Then el resultado es "ALERTA_DUPLICADA"

  @HU-G5-04 @api
  Scenario: No se puede crear una sexta alerta
    Given que inicié sesión como Ana
    And que tengo 5 alertas
    When creo una alerta de PAGOS con umbral S/ 500
    Then el resultado es "LIMITE_ALERTAS"

  # ------------------------------------------------------------------ HU-G5-06
  @HU-G5-06 @api
  Scenario: No se puede reanudar una alerta cuyo umbral supera el límite vigente
    Given que inicié sesión como Ana
    And que mi límite diario es S/ 250
    When reanudo la alerta de TRANSFERENCIAS con umbral S/ 300
    Then el resultado es "ALERTA_INVALIDA"

  # ------------------------------------------------------------------ HU-G5-08 (R-G5-05)
  @HU-G5-08 @api
  Scenario Outline: La alerta notifica al alcanzar o superar el umbral
    Given que inicié sesión como Ana
    When transfiero S/ <monto> al celular 912345678
    Then recibo <sms> SMS de alerta de consumo

    Examples:
      | monto  | sms |
      | 299.99 | 0   |
      | 300.00 | 1   |
      | 300.01 | 1   |

  @HU-G5-08 @api @DEF-03 @fail
  Scenario: Cada alerta notifica como máximo una vez por día
    Given que inicié sesión como Ana
    When transfiero S/ 300.00 al celular 912345678
    And transfiero S/ 10.00 al celular 912345678
    Then recibo 1 SMS de alerta de consumo

  @HU-G5-08 @api
  Scenario: Una alerta pausada no notifica
    Given que inicié sesión como Ana
    And que pausé la alerta de TRANSFERENCIAS con umbral S/ 300
    When transfiero S/ 300.00 al celular 912345678
    Then recibo 0 SMS de alerta de consumo

  # ------------------------------------------------------------------ HU-G5-05
  @HU-G5-05 @api
  Scenario: Veo mis alertas con su gasto de hoy
    Given que inicié sesión como Ana
    And que ya transferí S/ 120.00 hoy al celular 912345678
    When consulto mis alertas
    Then la alerta de TRANSFERENCIAS con umbral S/ 300 está ACTIVA
    And la alerta de TRANSFERENCIAS con umbral S/ 300 tiene un gasto de hoy de S/ 120.00

  # ------------------------------------------------------------------ HU-G5-07
  @HU-G5-07 @api
  Scenario: Una alerta eliminada deja de notificar
    Given que inicié sesión como Ana
    And que eliminé la alerta de TRANSFERENCIAS con umbral S/ 300
    When transfiero S/ 300.00 al celular 912345678
    Then recibo 0 SMS de alerta de consumo
