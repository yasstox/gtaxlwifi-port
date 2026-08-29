# Wi-Fi — Samsung Galaxy Tab A 10.1 2016 Wi-Fi (SM-T580 / gtaxlwifi)

## Matériel identifié

- Le Wi-Fi est un Qualcomm QCA6174 connecté par SDIO sur `mmc1`.
- Le DTS principal détecte la carte : `mmc1: new high speed SDIO card at address 0001`.
- Le DTS vendor décrit aussi un rail WLAN `cnss_dcdc_en` commandé par `gpa0-6`, avec un délai de démarrage de 4 ms.

## Test du driver ath10k

Une image de test a été construite avec :

- `CONFIG_ATH10K=m`;
- `CONFIG_ATH10K_SDIO=m`;
- le paquet `linux-firmware-ath10k`.

Le noyau démarre et charge correctement :

```text
ath10k_sdio
ath10k_core
ath
mac80211
cfg80211
````

Le rootfs contient notamment le firmware QCA6174 SDIO (`ath10k/QCA6174/hw3.0/firmware-sdio-6.bin.zst`).

## Résultat observé

Après le chargement du pilote, aucun `wlan0` n'est créé. Le journal noyau donne :

```text
ath10k_sdio mmc1:0001:1: unable to enable sdio function: -5
ath10k_sdio mmc1:0001:1: could not power on hif bus (-5)
ath10k_sdio mmc1:0001:1: could not probe fw (-5)
```

L'ajout expérimental du rail WLAN vendor comme `vmmc-supply` de `mmc1` n'a pas modifié ce résultat.

## Conclusion

Le blocage actuel n'est ni l'absence du driver, ni l'absence de firmware, ni la détection de la carte SDIO. Il survient lors de l'activation de la fonction SDIO 1 du QCA6174 (`-EIO`). Les essais de configuration et de DTS réalisés pour ce diagnostic ont été annulés et leurs branches locales supprimées.

## Pistes suivantes

1. Comparer les séquences CNSS vendor et le comportement du contrôleur DW-MMC lors de l'activation de la fonction SDIO.
2. Vérifier les lignes reset (`WLAN_EN`, `gpd3-6`) et host-wake, ainsi que leur séquençage réel.
3. Relever les transactions/erreurs MMC détaillées avec le debug MMC/SDIO activé, sans mélanger cette instrumentation à une correction fonctionnelle.

````

Pour le recréer directement dans le repo sans passer par un téléchargement :

```bash
cd /workspace/gtaxlwifi-port

cat > WIFI.md <<'EOF'
# Wi-Fi — Samsung Galaxy Tab A 10.1 2016 Wi-Fi (SM-T580 / gtaxlwifi)

## Matériel identifié

- Le Wi-Fi est un Qualcomm QCA6174 connecté par SDIO sur `mmc1`.
- Le DTS principal détecte la carte : `mmc1: new high speed SDIO card at address 0001`.
- Le DTS vendor décrit aussi un rail WLAN `cnss_dcdc_en` commandé par `gpa0-6`, avec un délai de démarrage de 4 ms.

## Test du driver ath10k

Une image de test a été construite avec :

- `CONFIG_ATH10K=m`;
- `CONFIG_ATH10K_SDIO=m`;
- le paquet `linux-firmware-ath10k`.

Le noyau démarre et charge correctement :

```text
ath10k_sdio
ath10k_core
ath
mac80211
cfg80211
````

Le rootfs contient notamment le firmware QCA6174 SDIO (`ath10k/QCA6174/hw3.0/firmware-sdio-6.bin.zst`).

## Résultat observé

Après le chargement du pilote, aucun `wlan0` n'est créé. Le journal noyau donne :

```text
ath10k_sdio mmc1:0001:1: unable to enable sdio function: -5
ath10k_sdio mmc1:0001:1: could not power on hif bus (-5)
ath10k_sdio mmc1:0001:1: could not probe fw (-5)
```

L'ajout expérimental du rail WLAN vendor comme `vmmc-supply` de `mmc1` n'a pas modifié ce résultat.

## Conclusion

Le blocage actuel n'est ni l'absence du driver, ni l'absence de firmware, ni la détection de la carte SDIO. Il survient lors de l'activation de la fonction SDIO 1 du QCA6174 (`-EIO`). Les essais de configuration et de DTS réalisés pour ce diagnostic ont été annulés et leurs branches locales supprimées.

## Pistes suivantes

1. Comparer les séquences CNSS vendor et le comportement du contrôleur DW-MMC lors de l'activation de la fonction SDIO.
2. Vérifier les lignes reset (`WLAN_EN`, `gpd3-6`) et host-wake, ainsi que leur séquençage réel.
3. Relever les transactions/erreurs MMC détaillées avec le debug MMC/SDIO activé, sans mélanger cette instrumentation à une correction fonctionnelle.
   EOF

