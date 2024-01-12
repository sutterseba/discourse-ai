# frozen_string_literal: true

describe ModelAccuracy do
  describe "#calculate_accuracy" do
    let(:accuracy) { ModelAccuracy.new(model: "test_model", classification_type: "test") }

    it "returns 0 if we had no feedback" do
      expect(accuracy.calculate_accuracy).to eq(0.0)
    end

    it "returns 50 if we had mixed feedback" do
      accuracy.flags_agreed = 1
      accuracy.flags_disagreed = 1

      expect(accuracy.calculate_accuracy).to eq(50)
    end

    it "always round the number" do
      accuracy.flags_agreed = 1
      accuracy.flags_disagreed = 2

      expect(accuracy.calculate_accuracy).to eq(33)
    end
  end

  describe ".adjust_model_accuracy" do
    let!(:accuracy) { ModelAccuracy.create!(model: "test_model", classification_type: "test") }

    def build_reviewable(klass, test_model_verdict)
      klass.new(payload: { "verdicts" => { "test_model" => test_model_verdict } })
    end

    it "does nothing if the reviewable is not generated by this plugin" do
      reviewable = build_reviewable(ReviewableFlaggedPost, true)

      described_class.adjust_model_accuracy(:approved, reviewable)

      expect(accuracy.reload.flags_agreed).to be_zero
      expect(accuracy.flags_disagreed).to be_zero
    end

    it "updates the agreed flag if reviewable was approved and verdict is true" do
      reviewable = build_reviewable(ReviewableAiPost, true)

      described_class.adjust_model_accuracy(:approved, reviewable)

      expect(accuracy.reload.flags_agreed).to eq(1)
      expect(accuracy.flags_disagreed).to be_zero
    end

    it "updates the disagreed flag if the reviewable was approved and verdict is false" do
      reviewable = build_reviewable(ReviewableAiPost, false)

      described_class.adjust_model_accuracy(:approved, reviewable)

      expect(accuracy.reload.flags_agreed).to be_zero
      expect(accuracy.flags_disagreed).to eq(1)
    end

    it "updates the disagreed flag if reviewable was rejected and verdict is true" do
      reviewable = build_reviewable(ReviewableAiPost, true)

      described_class.adjust_model_accuracy(:rejected, reviewable)

      expect(accuracy.reload.flags_agreed).to be_zero
      expect(accuracy.flags_disagreed).to eq(1)
    end

    it "updates the agreed flag if the reviewable was rejected and verdict is false" do
      reviewable = build_reviewable(ReviewableAiPost, false)

      described_class.adjust_model_accuracy(:rejected, reviewable)

      expect(accuracy.reload.flags_agreed).to eq(1)
      expect(accuracy.flags_disagreed).to be_zero
    end
  end
end
