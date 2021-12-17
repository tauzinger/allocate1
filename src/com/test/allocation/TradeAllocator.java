package com.test.allocation;

import java.io.*;
import java.util.*;

public class TradeAllocator {

    private final File tradesFile;
    private final File capitalFile;
    private final File holdingsFile;
    private final File targetsFile;
    private final File allocationsFile;

    List<Trade> tradeList = new ArrayList<>();
    List<Capital> capitalList = new ArrayList<>();
    List<Holding> holdingList = new ArrayList<>();
    List<Target> targetList = new ArrayList<>();

    public TradeAllocator(File tradesFile, File capitalFile, File holdingsFile, File targetsFile, File allocationsFile) {
        this.tradesFile = tradesFile;
        this.capitalFile = capitalFile;
        this.holdingsFile = holdingsFile;
        this.targetsFile = targetsFile;
        this.allocationsFile = allocationsFile;
    }

    public static void main(String[] args) throws Exception {
        File tradesFile = new File(args[0]);
        File capitalFile = new File(args[1]);
        File holdingsFile = new File(args[2]);
        File targetsFile = new File(args[3]);
        File allocationsFile = new File(args[4]);
        TradeAllocator allocator = new TradeAllocator(tradesFile, capitalFile, holdingsFile, targetsFile, allocationsFile);
        allocator.readSheets();
        allocator.overview();
        allocator.allInPosition();
    }

    private void allInPosition() {
        tradeList.stream().forEach(tr -> {
            final double allInPosition = tr.quantity+
            holdingList.stream().
                    filter(f-> tr.stock.equals(f.stock)).
                    mapToDouble(h-> h.quantity).sum();
            System.out.println("allInPosition " + tr.stock + " " + allInPosition);
        });
    }

    private void overview() {
        // John's GOOGLE holdings
        capitalList.stream().forEach(c -> {
            tradeList.stream().forEach(tr-> {
                targetList.stream().filter(tg -> tg.account.equals(c.account) &&
                        tg.stock.equals(tr.stock)).forEach(tg-> {
                            double targetMarketValue = c.capital * 0.01 * tg.targetPercent;
                    System.out.println(c.account + " " + tr.stock + " " + tg.targetPercent + " targetMarketValue " + targetMarketValue);
                    final double maxShares = targetMarketValue / tr.price;
                    System.out.println("maxShares "+maxShares);
                    holdingList.stream().filter(hl -> hl.account.equals(c.account) &&
                            hl.stock.equals(tr.stock)).forEach(hl -> {
                        double additional = maxShares - hl.quantity;
                        System.out.println("additional "+additional);


                    });

                });
            });
        });
    }

    private void readSheets() throws Exception {
        readTrades();
        readCapital();
        readHoldings();
        readTargets();
    }

    private void readTargets() throws Exception {
        Scanner s = new Scanner(targetsFile);
        s.nextLine();
        while(s.hasNext()) {
            String line = s.nextLine();
            String[] arr = line.split(",");
            String stock = arr[0];
            String account = arr[1];
            double targetPercent = Double.parseDouble(arr[2]);
            Target target = new Target(stock, account, targetPercent);
            targetList.add(target);
            System.out.println(target.toString());
        }

    }

    private void readHoldings() throws Exception {
        Scanner s = new Scanner(holdingsFile);
        s.nextLine();
        while(s.hasNext()) {
            String line = s.nextLine();
            String[] arr = line.split(",");
            String account = arr[0];
            String stock = arr[1];
            double quantity = Double.parseDouble(arr[2]);
            double price = Double.parseDouble(arr[3]);
            double marketValue = Double.parseDouble(arr[4]);
            Holding holding = new Holding(account, stock, quantity, price, marketValue);
            holdingList.add(holding);
            System.out.println(holding.toString());
        }
    }

    private void readCapital() throws Exception {
        Scanner s = new Scanner(capitalFile);
        s.useDelimiter(",");
        s.nextLine();
        while(s.hasNext()) {
            String line = s.nextLine();
            String[] arr = line.split(",");
            String account = arr[0];
            Double capital = Double.parseDouble(arr[1]);
            Capital cap = new Capital(account, capital);
            capitalList.add(cap);
            System.out.println(cap.toString());
        }
    }

    private void readTrades() throws Exception {
        Scanner s = new Scanner(tradesFile);
        s.useDelimiter(",");
        s.nextLine();
        while(s.hasNext()) {
            String line = s.nextLine();
            String [] arr = line.split(",");
            String stock = arr[0];
            String type = arr[1];
            Double quantity = Double.parseDouble(arr[2]);
            Double price = Double.parseDouble(arr[3]);
            Trade trade = new Trade(stock, type, quantity, price);
            tradeList.add(trade);
            System.out.println(trade.toString());
        }
    }

    class Trade {
        public Trade(String stock, String type, double quantity, double price) {
            this.stock = stock;
            this.type = type;
            this.quantity = quantity;
            this.price = price;
        }

        @Override
        public String toString() {
            return "Trade{" +
                    "stock='" + stock + '\'' +
                    ", type='" + type + '\'' +
                    ", quantity=" + quantity +
                    ", price=" + price +
                    '}';
        }

        private final String stock;
        private final String type;
        private final double quantity;
        private final double price;
    }

    class Capital {
        public Capital(String account, double capital) {
            this.account = account;
            this.capital = capital;
        }

        private final String account;
        private final double capital;

        @Override
        public String toString() {
            return "Capital{" +
                    "account='" + account + '\'' +
                    ", capital=" + capital +
                    '}';
        }
    }

    class Holding {
        public Holding(String account, String stock, double quantity, double price, double marketValue) {
            this.account = account;
            this.stock = stock;
            this.quantity = quantity;
            this.price = price;
            this.marketValue = marketValue;
        }

        private final String account;
        private final String stock;
        private final double quantity;
        private final double price;
        private final double marketValue;

        @Override
        public String toString() {
            return "Holding{" +
                    "account='" + account + '\'' +
                    ", stock='" + stock + '\'' +
                    ", quantity=" + quantity +
                    ", price=" + price +
                    ", marketValue=" + marketValue +
                    '}';
        }
    }

    class Target {
        public Target(String stock, String account, double targetPercent) {
            this.stock = stock;
            this.account = account;
            this.targetPercent = targetPercent;
        }

        private final String stock;
        private final String account;
        private final double targetPercent;

        @Override
        public String toString() {
            return "Target{" +
                    "stock='" + stock + '\'' +
                    ", account='" + account + '\'' +
                    ", targetPercent=" + targetPercent +
                    '}';
        }
    }

    class Allocation {
        public Allocation(String account, String stock, double quantity) {
            this.account = account;
            this.stock = stock;
            this.quantity = quantity;
        }

        private final String account;
        private final String stock;
        private final double quantity;
    }

    class Overview {
        String account;
        double capital;
        String stock;
        double quantityHeld;
        double target;
        double targetMarketValue;
        double maxShares;
        double allInPosition;
        double suggestedFinalPosition;
        double suggestedTradeAllocation;
    }




}
