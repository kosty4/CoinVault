<template>
  <v-app>
    <v-app-bar app>
      <!-- -->
      <div class="d-flex align-center ma-3">
        <h2>EthVault</h2>
      </div>

      <template v-slot:extension>
        <v-tabs
          v-model="selectedTab"
          centered
          slider-color="grey darken-1"
          flat
        >
          <v-tab :href="`#tab-${0}`" :disabled="userVaults.length == 0">
            Your Vaults
          </v-tab>
          <v-tab :href="`#tab-${1}`"> New Vault </v-tab>
        </v-tabs>
      </template>

      <v-spacer></v-spacer>
      <v-footer class="mt-3">
        <v-row justify="center" no-gutters>
          <template v-if="!metamaskInstalled">
            <v-btn
              class="mx-3"
              outlined
              rounded
              text
              v-on:click="startOnboarding"
              :disabled="onBoardingButtonDisabeld"
            >
              Click here to install Metamask!
            </v-btn>
          </template>
          <template v-if="metamaskInstalled">
            <div>
              <div v-if="!metamaskConnected">
                <v-btn text rounded v-on:click="connectToWallet">
                  <v-icon left>mdi-wallet</v-icon>
                  Connect
                </v-btn>
              </div>
              <div v-else-if="metamaskConnected">
                <v-btn text rounded>
                  <v-icon left>mdi-wallet</v-icon>
                  {{ this.$store.state.accountWithWallets.slice(0, 3) }}...{{
                    this.$store.state.accountWithWallets.slice(-3)
                  }}
                </v-btn>
              </div>
            </div>
          </template>

          <v-btn text rounded> Home </v-btn>
          <v-btn text rounded> About </v-btn>
        </v-row>
      </v-footer>
    </v-app-bar>

    <!-- Sizes your content based upon application components -->
    <v-main>
      <!-- Provides the application the proper gutter -->
      <v-container fluid>
        <v-row justify="center" class="mt-4">
          <v-col sm="7">
            <v-tabs-items v-model="selectedTab">
              <v-tab-item :value="`tab-${0}`">
                <div class="d-flex flex-wrap" :key="rerenderList">
                  <vault-card
                    v-for="(item, index) in userVaults"
                    :key="`${rerenderList}-${index}`"
                    :vaultDeposit="parseFloat(userVaults[index][0])"
                    :vaultMaturity="parseFloat(userVaults[index][1])"
                    :vaultName="userVaults[index][4]"
                    :vaultID="index"
                  />
                </div>
              </v-tab-item>

              <v-tab-item :value="`tab-${1}`">
                <v-row justify="center" class="mt-4">
                  <v-col sm="6">
                    <v-card elevation="2" outlined class="lg ma-2">
                      <v-card-text>
                        <v-form>
                          <v-container>
                            <v-row class="ma-2">
                              <v-text-field
                                label="Vault Name"
                                solo
                                required
                                v-model="newVaultName"
                              ></v-text-field>
                            </v-row>
                            <div class="ma-2">
                              <v-dialog
                                ref="dateSelectDialog"
                                v-model="dateSelectDialog"
                                :return-value.sync="newVaultDate"
                                persistent
                                width="290px"
                              >
                                <template v-slot:activator="{ on, attrs }">
                                  <v-text-field
                                    v-model="newVaultDate"
                                    label="Select release date"
                                    prepend-icon="mdi-calendar"
                                    readonly
                                    v-bind="attrs"
                                    v-on="on"
                                  ></v-text-field>
                                </template>
                                <v-date-picker
                                  v-model="newVaultDate"
                                  :active-picker.sync="activePicker"
                                  :min="minDate"
                                  :max="maxDate"
                                  @change="saveDate"
                                >
                                  <v-spacer></v-spacer>
                                  <v-btn
                                    text
                                    color="primary"
                                    @click="dateSelectDialog = false"
                                  >
                                    Cancel
                                  </v-btn>
                                  <v-btn text color="primary">
                                    OK
                                  </v-btn></v-date-picker
                                >
                              </v-dialog>
                            </div>
                            <v-btn
                              v-on:click="createVault"
                              color="success"
                              dark
                              class="mt-6"
                            >
                              Create Vault
                            </v-btn>
                          </v-container>
                        </v-form>
                      </v-card-text>
                    </v-card>
                  </v-col>
                </v-row>
              </v-tab-item>
            </v-tabs-items>
          </v-col>
        </v-row>

        <v-snackbar
          v-model="snackbar"
          bottom
          color="success"
          outlined
          text
          absolute
          timeout="2500"
        >
          Connected to Matamask!

          <template v-slot:action="{ attrs }">
            <v-btn text v-bind="attrs" @click="snackbar = false"> Close </v-btn>
          </template>
        </v-snackbar>

        <!-- If using vue-router -->
        <!-- <router-view></router-view> -->
      </v-container>
    </v-main>

    <v-footer app>
      <!-- -->
    </v-footer>
  </v-app>
</template>

<script>
import MetaMaskOnboarding from "@metamask/onboarding";

import contractAbi from "../../../build/contracts/EthVault.json";

import VaultCard from "./VaultCard.vue";

export default {
  name: "Home",
  data: () => ({
    selectedTab: "tab-1",
    snackbar: false,

    activePicker: null,
    newVaultDate: null,
    newVaultName: "",

    rerenderList: 0,

    dateSelectDialog: false,

    minDate: null,
    maxDate: null,
    modal: false,

    userVaults: [],
    contractAbi: contractAbi,

    metamaskInstalled: Boolean,
    onBoardingButtonDisabeld: false,
    metamaskConnected: false,
  }),
  components: {
    VaultCard,
  },
  methods: {
    isMetaMaskInstalled() {
      const { ethereum } = window;
      return Boolean(ethereum && ethereum.isMetaMask);
    },
    startOnboarding() {
      this.onBoardingButtonDisabeld = true;
      const onboarding = new MetaMaskOnboarding();
      onboarding.startOnboarding();
    },

    async getVaults() {
      return await this.$store.state.contract.get();
    },

    async connectToWallet() {

      await this.$store.dispatch("registerWeb3");
      await this.$store.dispatch("registerContract");

      this.metamaskConnected = true;
      this.snackbar = true;
      //Get user created vaults
      this.userVaults = await this.getVaults();
      this.forceRerender();
    },

    async createVault() {
      let newVaultMaturity = new Date(this.newVaultDate).getTime() / 1000;
      let currentTime = new Date().getTime() / 1000;

      let timedifference = newVaultMaturity - currentTime;
      timedifference = Math.round(timedifference);

      const newVaultTx = await this.$store.state.contract
        .createNewVault(timedifference, this.newVaultName);

      await newVaultTx.wait();

      this.userVaults = await this.getVaults();
      this.forceRerender();
    },

    saveDate(newVaultDate) {
      this.$refs.dateSelectDialog.save(newVaultDate);
    },

    forceRerender() {
      this.rerenderList += 1;
    },
  },
  created: function () {
    var today = new Date();
    var after = new Date();
    this.minDate = today.toISOString().split("T")[0];

    after.setDate(after.getDate() + 5 * 365);
    this.maxDate = after.toISOString().split("T")[0];

    this.metamaskInstalled = this.isMetaMaskInstalled();
  },
  beforeMount() {
    this.userVaults = [];
  },
  watch: {
    dateSelectDialog(val) {
      val && setTimeout(() => (this.activePicker = "YEAR"));
    },
  },
};
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
h3 {
  margin: 40px 0 0;
}
ul {
  list-style-type: none;
  padding: 0;
}
li {
  display: inline-block;
  margin: 0 10px;
}
a {
  color: #42b983;
}
</style>