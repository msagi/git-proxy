const Step = require('../../actions').Step;
const db = require('../../../db');

// Execute if the repo is approved
const exec = async (req, action, authorisedList = db.getRepos) => {
  const step = new Step('checkRepoInAuthorisedList');

  const list = await authorisedList();
  console.log(list);

  const found = list.find((x) => {
    const targetName = action.repo.url.toLowerCase();
    const allowedName = x.url.toLowerCase();
    console.log(`${targetName} = ${allowedName}`);
    return targetName === allowedName;
  });

  console.log(found);

  if (!found) {
    console.log('not found');
    step.error = true;
    step.log(`repo '${action.repo.url}' is not in the authorisedList, ending`);
    console.log('setting error');
    step.setError(`Rejecting repo '${action.repo.url}' not in the authorisedList`);
    action.addStep(step);
    return action;
  }

  console.log('found');
  step.log(`repo '${action.repo.url}' is in the authorisedList`);
  action.addStep(step);
  return action;
};

exec.displayName = 'checkRepoInAuthorisedList.exec';
exports.exec = exec;
