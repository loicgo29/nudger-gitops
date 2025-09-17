Feature: Persistance MySQL
  Scenario: Vérifier que les données persistent après redémarrage
    Given une base MySQL disponible
    When je crée une table "bdd_test" et insère une ligne
    And je supprime le pod MySQL
    Then la ligne est toujours présente après redémarrage
