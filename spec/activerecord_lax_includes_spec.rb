# frozen_string_literal: true

describe ActiveRecordLaxIncludes do
  it 'raises association not found error by default' do
    Comment.create(commentable: Project.new)

    expect { Comment.includes(commentable: :project).to_a }
      .to raise_error(ActiveRecord::AssociationNotFoundError)
  end

  describe '.lax_includes_enabled?' do
    subject { ActiveRecord.lax_includes_enabled? }

    it { is_expected.to be_falsey }
  end

  describe '.lax_includes' do
    around do |example|
      ActiveRecord.lax_includes { example.run }
    end

    it { expect(ActiveRecord).to be_lax_includes_enabled }

    it 'fails silently' do
      Project.create.tap { |project| Comment.create(commentable: project) }

      expect { Comment.includes(commentable: :project).to_a }.not_to raise_error
    end

    it 'includes requested associations' do
      project = Project.create
      comment =
        Task
        .create(project: project)
        .then { |task| Comment.create(commentable: task) }

      expect(Comment.includes(commentable: :project).to_a)
        .to match_array(comment)
    end

    context 'when using aside bullet gem' do
      around do |example|
        Bullet.enable = true
        example.run
        Bullet.enable = false
      end

      it 'does not raise errors' do
        Project.create.tap { |project| Comment.create(commentable: project) }

        expect { Comment.includes(commentable: :project).to_a }.not_to raise_error
      end
    end
  end
end
